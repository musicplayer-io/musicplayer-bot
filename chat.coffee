{EventEmitter} = require "events"
_ = require "lodash"

config = require "./config.js"
Messages = require "./messages"

YouTube = require "youtube-node"
youTube = new YouTube()
youTube.setKey config.youtube

fs = require('fs')
youtubedl = require('youtube-dl')


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
	else
		cb Commands.Undefined

Commands =
	Help:
		regex: /^\/help/gm
		type: "Help"
	YoutubeEmpty:
		regex: /^\/youtube?$/gm
		type: "YoutubeEmpty"
	YoutubeGet:
		regex: /^\/youtube (.*)$/gm
		type: "YoutubeGet"
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
	Commands:
		regex: /^\/commands$/gm
		type: "Commands"

Replies =
	Commands:
		keyboard: ["/search", "/help", "/get", "/reddit"]

searchYoutube = (text) ->
	console.log "Searching", text
	youTube.search text, 3, (err, result) =>
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
		@sendMessage Messages.YoutubeStarted info
		console.log 'Download started', info._filename
		fileLocation = "#{__dirname}/downloads/#{info._filename}"
		fileStream = fs.createWriteStream(fileLocation)
		video.pipe(fileStream)
		video.on "end", () =>
			console.log "Download Finished", info._filename
			@sendMessage Messages.YoutubeDone()
			@sendChatAction "upload_audio"
			@sendAudio fileLocation

class Chat extends EventEmitter
	constructor: (@bot, chat, msg) ->
		_.assign @, chat
		console.log "Hello", @id, @first_name
		@on "message", @readMessage
		@mode = ""
		@readMessage msg

	cancel: () ->
		@mode = ""
		@sendMessage Messages.Ok()

	readMessage: (msg) ->
		console.log "@"+@first_name, msg
		if @mode is "youtubeselection"
			return @cancel() if _.endsWith _.trim(msg), "cancel"
			words = _.words(msg)
			if _.intersection(_.lower(words), ["first", "1", "one"]).length
				getYoutubeAudio.call @, _.first(@youtubeSongs).id.videoId
			else if _.intersection(_.lower(words), ["second", "2", "two"]).length
				getYoutubeAudio.call @, @youtubeSongs[1].id.videoId
			else if _.intersection(_.lower(words), ["third", "3", "three"])
				getYoutubeAudio.call @, @youtubeSongs[2].id.videoId
			else if _.intersection(_.lower(words), ["last"]).length
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
					@sendMessage Messages.Greet {user: @first_name}
				
				when "Undefined"
					@sendMessage Messages.Undefined {user: @first_name}
				
				when "Help"
					@sendMessage Messages.Help {user: @first_name}, Replies.Commands

				when "Commands"
					@sendMessage Messages.Help {user: @first_name}, Replies.Commands
								

				when "YoutubeEmpty"
					@sendMessage Messages.YoutubeEmpty()
					@sendMessage Messages.SearchStart()
					@mode = "search"
				
				when "YoutubeGet"
					getYoutubeAudio.call @, arg1

				when "SearchStart"
					@sendMessage Messages.SearchStart()
					@mode = "search"
				
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
			@sendMessage Messages.YoutubeDownload @youtubeSongs,
				keyboard: _.mapKeys @youtubeSongs, (i) -> "/#{i}"
		, 500

	sendMessage: (text, replies) ->
		if replies?
			@bot.sendMessage @id, text, {reply_markup: replies}
		else
			@bot.sendMessage @id, text
	sendChatAction: (action) ->
		@bot.sendChatAction @id, action
	sendAudio: (audio, caption) ->
		@bot.sendAudio @id, audio, {caption: caption}
	sendPhoto: (audio) ->
		@bot.sendPhoto @id, photo

module.exports = Chat	