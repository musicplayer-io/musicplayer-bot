{EventEmitter} = require "events"
_ = require "lodash"

config = require "./config.js"
Messages = require "./messages"

YouTube = require "youtube-node"
youTube = new YouTube()
youTube.setKey config.youtube

fs = require('fs')
path = require('path')
yaml = require "js-yaml"
youtubedl = require('youtube-dl')

subs = yaml.safeLoad fs.readFileSync(path.join(__dirname, "/subreddits.yaml"), "utf8")

request = require("request")

reddit = (sub, callback) ->
	sub = sub.trim()
	request.get "http://www.reddit.com/r/#{sub}/search.json?q=site%3Ayoutube&sort=new&restrict_sr=on&t=all",
		(err, resp, body) ->
			return callback false if err?
			data = JSON.parse body
			return callback false if not data.data?
			list = _.map data.data.children, (c) -> c.data
			callback list

parseCommand = (msg, cb) ->
	if msg.match Commands.Help.regex
		cb Commands.Help
	else if msg.match Commands.YoutubeEmpty.regex
		cb Commands.YoutubeEmpty
	else if msg.match Commands.YoutubeGet.regex
		matches = Commands.YoutubeGet.regex.exec msg
		cb Commands.YoutubeGet, matches[1]
	else if msg.match Commands.SearchStart.regex
		cb Commands.SearchStart
	else if msg.match Commands.Search.regex
		matches = Commands.Search.regex.exec msg
		cb Commands.Search, matches[1]
	else if msg.match Commands.Commands.regex
		cb Commands.Commands
	else if msg.match(Commands.Greet.regex) or _.intersection(_.lower(_.words(msg)), ["hello", "hey", "yo", "hi", "greetings"]).length
		cb Commands.Greet
	else if msg.match Commands.YoutubeLink.regex
		cb Commands.YoutubeLink, getYoutubeID(msg)
	else if msg.match Commands.Reddit.regex
		matches = Commands.Reddit.regex.exec msg
		if matches[2]
			cb Commands.Reddit, matches[2]
		else
			cb Commands.RedditStart
	else
		cb Commands.Undefined

getYoutubeID = (url) ->
	matches = Commands.YoutubeLink.regex.exec(url)
	return matches[1] if matches? and matches[1]

Commands =
	Help:
		regex: /^\/help/gm
		type: "Help"
	YoutubeEmpty:
		regex: /^\/youtube?$/gm
		type: "YoutubeEmpty"
	YoutubeGet:
		regex: /^\/youtube[ _](.*)$/gm
		type: "YoutubeGet"
	YoutubeLink:
		regex: /(?:https?:\/\/)?(?:youtu\.be\/|(?:www\.)?youtube\.com\/watch(?:\.php)?\?.*v=)([a-zA-Z0-9\-_]+)/gm
		type: "YoutubeLink"
	SearchStart:
		regex: /^\/search$/gm
		type: "SearchStart"
	Search:
		regex: /^\/search (.*)/gm
		type: "Search"
	Undefined:
		type: "Undefined"
	Greet:
		regex: /^\/start$/gm
		type: "Greet"
	Settings:
		regex: /^\/start$/gm
		type: "Settings"
	Commands:
		regex: /^\/commands$/gm
		type: "Commands"
	Reddit:
		regex: /\/(reddit|r\/|r\_)\s?(.*)/gm
		type: "Reddit"
	RedditStart:
		type: "RedditStart"

Replies =
	Commands:
		keyboard: [["/search", "/reddit"], ["/help", "/settings"]]
		resize_keyboard: true

searchYoutube = (text) ->
	console.log "Searching", text
	youTube.search text, @settings.limit, (err, result) =>
		if (err)
			console.error err
			return @sendMessage Messages.Error
		result.items = _.filter result.items, (i) -> i.id.videoId
		@youtubeSongs = result.items
		@sendYoutubeSelection()

getYoutubeAudio = (youtubeId) ->
	@sendChatAction "record_audio"
	video = youtubedl "http://www.youtube.com/watch?v=#{youtubeId}", ["--format=bestaudio"], { cwd: __dirname + "/downloads/" }
	video.on "info", (info) =>
		if (info.size / 1000000) > 20
			@sendMessage Messages.YoutubeTooLarge({id: youtubeId}), {disable_web_page_preview: true}
			video.emit "end"
			console.log "Download Cancelled"
		else
			@sendMessage Messages.YoutubeStarted info
			console.log 'Download started', info._filename
			fileLocation = "#{__dirname}/downloads/#{info._filename}"
			fileStream = fs.createWriteStream(fileLocation)
			video.pipe(fileStream)
			@mode = "download"
			video.on "end", () =>
				console.log "Download Finished", info._filename
				@sendMessage Messages.YoutubeDone()
				@sendChatAction "upload_audio"
				@sendAudio fileLocation
					.then (x) -> removeFile fileLocation

removeFile = (location) ->
	fs.unlink location, (err) ->
		return console.error err if err?
		console.log "Download Removed", location

catEmojis = "😺 😸 😻 😽 😼 🙀 😿 😹 😾".split(" ")
catEmoji = () ->
	catEmojis[Math.floor(Math.random() * catEmojis.length)]

class Chat extends EventEmitter
	constructor: (@bot, chat, msg) ->
		_.assign @, chat
		console.log "Hello", @id, @first_name
		@on "message", @readMessage
		@mode = ""
		@readMessage msg

	settings:
		limit: 5

	cancel: () ->
		@mode = ""
		@sendMessage Messages.Ok()

	readMessage: (msg) ->
		console.log "@"+@first_name, msg
		if @mode is "download"
			return @cancel() if _.endsWith _.trim(msg), "cancel"

		if @mode is "youtubeselection"
			return @cancel() if _.endsWith _.trim(msg), "cancel"
			words = _.words(msg)
			if _.intersection(_.lower(words), ["first", "1", "one"]).length
				getYoutubeAudio.call @, _.first(@youtubeSongs).id.videoId
				@sendMessage "First one it is."
			else if _.intersection(_.lower(words), ["second", "2", "two"]).length
				getYoutubeAudio.call @, @youtubeSongs[1].id.videoId
				@sendMessage "Good choice, let me grab that for you."
			else if _.intersection(_.lower(words), ["third", "3", "three"])
				getYoutubeAudio.call @, @youtubeSongs[2].id.videoId
				@sendMessage "Alright, one music coming up."
			else if _.intersection(_.lower(words), ["fourth", "four", "4"])
				getYoutubeAudio.call @, @youtubeSongs[3].id.videoId
				@sendMessage "One moment."
			else if _.intersection(_.lower(words), ["five", "5", "fifth"])
				getYoutubeAudio.call @, @youtubeSongs[4].id.videoId
				@sendMessage "Okay then. You can wait now."
			else if _.intersection(_.lower(words), ["last"]).length
				@sendMessage "Last one? Okay, hold on."
				getYoutubeAudio.call @, _.last(@youtubeSongs).id.videoId
			@mode = ""
			return
			
		if not (_.startsWith msg, "/") and @mode is "search"
			@sendChatAction "typing"
			searchYoutube.call @, msg
			@mode = ""
			return

		parseCommand msg, (command, arg1) =>
			switch command.type
				when "Greet"
					@sendMessage Messages.Greet({user: @first_name}),
						disable_web_page_preview: true
						reply_markup: Replies.Commands
				
				when "Undefined"
					@sendMessage Messages.Undefined({user: @first_name})
					@sendRandom()
				
				when "Help"
					@sendMessage Messages.Help({user: @first_name}), {reply_markup: Replies.Commands}

				when "Commands"
					@sendMessage Messages.Help({user: @first_name}), {reply_markup: Replies.Commands}

				when "YoutubeEmpty"
					@sendMessage Messages.YoutubeEmpty()
					@sendMessage Messages.SearchStart()
					@mode = "search"
				
				when "YoutubeGet"
					getYoutubeAudio.call @, arg1

				when "YoutubeLink"
					# @sendMessage Messages.ToutubeLink()
					getYoutubeAudio.call @, arg1

				when "SearchStart"
					@sendMessage Messages.SearchStart()
					@mode = "search"

				when "Reddit"
					@sendMessage Messages.Reddit({sub: arg1})
					@sendChatAction "typing"
					reddit.call @, arg1, (list) =>
						if list is false
							return @sendMessage Messages.RedditEmpty()
						list = _.sample list, @settings.limit
						@sendMessage Messages.RedditList {sub: arg1, list: list}
						_.forEach list, (item) =>
							item.id = getYoutubeID item.url
							@sendMessage Messages.RedditLink item


				when "RedditStart"
					randomSelection = _.sample(_.shuffle(_.flatten(_.values(subs))), @settings.limit)
					@sendMessage Messages.RedditStart {subs: randomSelection}
				
				when "Search"
					@sendChatAction "typing"
					searchYoutube.call @, arg1
					@mode = ""

	sendYoutubeSelection: () ->
		_.forEach @youtubeSongs, (item, i) =>
			item.i = i + 1;
			@sendMessage Messages.YoutubeResult item
		@mode = "youtubeselection"
		setTimeout () =>
			@sendMessage Messages.YoutubeDownload(@youtubeSongs),
				keyboard: _.mapKeys @youtubeSongs, (i) -> "/#{i}"
		, 500

	sendMessage: (text, options) ->
		if options?
			@bot.sendMessage @id, text, options
			# {reply_markup: replies}
		else
			@bot.sendMessage @id, text
	sendChatAction: (action) ->
		@bot.sendChatAction @id, action
	sendAudio: (audio, caption) ->
		@bot.sendAudio @id, audio, {caption: caption}
	sendPhoto: (audio) ->
		@bot.sendPhoto @id, photo
	sendRandom: () ->
		
		switch (Math.round Math.random() * 2)
			when 1
				console.log "cat facts!"
				request.get "https://catfacts-api.appspot.com/api/facts", (err, resp, body) =>
					@sendMessage catEmoji() + _.first(JSON.parse(body).facts)
				

module.exports = Chat	