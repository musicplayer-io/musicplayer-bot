{EventEmitter} = require "events"
_ = require "lodash"
fs = require "fs"
path = require('path')
yaml = require "js-yaml"
request = require "request"

# Bot
config = require "./config.json"
Messages = require "./messages"
Replies = require "./replies"
parseCommand = require "./commands"
Commands = parseCommand.Commands

# YouTube
YouTube = require "youtube-node"
youTube = new YouTube()
youTube.setKey config.youtube
youtubedl = require "youtube-dl"


# List of subreddits
subs = yaml.safeLoad fs.readFileSync(path.join(__dirname, "/subreddits.yaml"), "utf8")

# Gets listings from Reddit
#
# @param [String] sub The subreddit to search
# @param [Function] callback Function to execute, returns a list
reddit = (sub, callback) ->
	sub = sub.trim()
	request.get "http://www.reddit.com/r/#{sub}/search.json?q=site%3Ayoutube&sort=new&restrict_sr=on&t=all",
		(err, resp, body) ->
			return callback false if err?
			try
				data = JSON.parse body
			catch e
				return callback false
			return callback false if not data.data?
			list = _.map data.data.children, (c) -> c.data
			callback list

# Get YouTube id from URL
#
# @param [String] url The URL to parse
getYoutubeID = (url) ->
	matches = Commands.YoutubeLink.regex.exec(url)
	return matches[1] if matches? and matches[1]

# Searches YouTube
#
# @param [String] text Text query to search for
searchYoutube = (text) ->
	console.log "Searching", text
	youTube.search text, @settings.limit, (err, result) =>
		if (err)
			console.error err
			return @sendMessage Messages.Error
		result.items = _.filter result.items, (i) -> i.id.videoId
		@youtubeSongs = result.items
		@sendYoutubeSelection()

# Download audio from YouTube
#
# @option option [Number] youtubeId ID of the YouTube video
# @option option [String] url URL of the YouTube video
getYoutubeAudio = (youtubeId, url) ->
	@sendChatAction "record_audio"
	if youtubeId?
		video = youtubedl "http://www.youtube.com/watch?v=#{youtubeId}", ["--format=bestaudio"], { cwd: __dirname + "/downloads/" }
	else if url?
		video = youtubedl url, ["--format=bestaudio"], { cwd: __dirname + "/downloads/" }
	video.on "error", (err) =>
		message = err.toString().split("\n")[1]
		return @sendMessage Messages.Error msg: message.substr(message.indexOf("YouTube said:"))
	video.on "exit", () =>
		console.log "exit", arguments
	video.on "info", (info) =>
		if (info.size / 1000000) > 20
			@sendMessage Messages.YoutubeTooLarge({id: youtubeId}),
				disable_web_page_preview: true
				reply_markup: Replies.Commands
			@mode = ""
			video.emit "end"
			console.log "Download Cancelled"
		else
			@sendMessage Messages.YoutubeStarted info, {reply_markup: Replies.Hide}
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

# Remove downloaded file
#
# @param [String] location File path to the file
removeFile = (location) ->
	fs.unlink location, (err) ->
		return console.error err if err?
		console.log "Download Removed", location

# Chat class
#
# @event message
class Chat extends EventEmitter

	# Construct a new chat
	#
	# @param [TelegramBot] bot The Telegram Bot to send messages to
	# @param [Chat] chat A Telegram user
	# @param [String] msg The first incoming message
	constructor: (@bot, chat, msg) ->
		_.assign @, chat
		console.log "Hello", @id, @first_name
		@on "message", @readMessage
		@mode = ""
		@readMessage msg

	# Settings for this chat
	settings:
		limit: 6

	# Cancel current operation and send Ok Message
	cancel: () ->
		@mode = ""
		@sendMessage Messages.Ok()

	# Reads the next incoming message
	#
	# @param [String] msg The next incoming message
	readMessage: (msg) ->
		console.log "@"+@first_name, msg
		if @mode is "settings"
			return @cancel() if _.endsWith _.trim(msg), "cancel"

		if @mode is "download"
			return @cancel() if _.endsWith _.trim(msg), "cancel"

		if @mode is "redditselection"
			return @cancel() if _.endsWith _.trim(msg), "cancel"
			item = _.find @redditList, (i) -> i.title is msg
			if item?
				@sendChatAction "typing"
				return getYoutubeAudio.call @, null, item.url

		if @mode is "youtubeselection"
			return @cancel() if _.endsWith _.trim(msg), "cancel"

			item = _.find @youtubeSongs, (i) -> i.snippet.title is msg
			if item?
				@sendMessage item.snippet.title + " it is."
				return getYoutubeAudio.call @, item.id.videoId

			words = _.words(msg)
			console.log _.intersection(_.lower(words), ["third", "3", "three"])
			if _.intersection(_.lower(words), ["first", "1", "one"]).length
				getYoutubeAudio.call @, _.first(@youtubeSongs).id.videoId
				@sendMessage "First one it is."
			else if _.intersection(_.lower(words), ["second", "2", "two"]).length
				getYoutubeAudio.call @, @youtubeSongs[1].id.videoId
				@sendMessage "Good choice, let me grab that for you."
			else if _.intersection(_.lower(words), ["third", "3", "three"]).length
				getYoutubeAudio.call @, @youtubeSongs[2].id.videoId
				@sendMessage "Alright, one music coming up."
			else if _.intersection(_.lower(words), ["fourth", "four", "4"]).length
				getYoutubeAudio.call @, @youtubeSongs[3].id.videoId
				@sendMessage "One moment."
			else if _.intersection(_.lower(words), ["five", "5", "fifth"]).length
				getYoutubeAudio.call @, @youtubeSongs[4].id.videoId
				@sendMessage "Okay then. You can wait now."
			else if _.intersection(_.lower(words), ["last"]).length
				@sendMessage "Last one? Okay, hold on."
				getYoutubeAudio.call @, _.last(@youtubeSongs).id.videoId
			else
				@sendMessage Messages.Undefined({user: @first_name})
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
					@sendMessage Messages.Undefined({user: @first_name}),
						reply_markup: Replies.Commands
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
					getYoutubeAudio.call @, arg1

				when "SearchStart"
					@sendMessage Messages.SearchStart(), {reply_markup: Replies.Hide}
					@mode = "search"

				when "Reddit"
					@sendMessage Messages.Reddit({sub: arg1})
					@sendChatAction "typing"
					reddit.call @, arg1, (list) =>
						if list is false
							return @sendMessage Messages.RedditEmpty()
						list = _.sample list, @settings.limit
						list = _.map list, (i) -> i.id = getYoutubeID i.url; i
						@redditList = list
						@sendMessage Messages.RedditList {sub: arg1, list: @redditList}
						_.forEach @redditList, (item) =>
							@sendMessage Messages.RedditLink item
						setTimeout () =>
							@sendMessage Messages.YoutubeDownload(@redditList),
								reply_markup: JSON.stringify
									keyboard: _.chunk _.map @redditList, (i) -> "#{i.title}"
									resize_keyboard: true
									one_time_keyboard: true
						, 500
						@mode = "redditselection"


				when "RedditStart"
					randomSelection = _.sample(_.shuffle(_.flatten(_.values(subs))), @settings.limit)
					@sendMessage Messages.RedditStart({subs: randomSelection}),
						reply_markup: JSON.stringify
							keyboard: _.chunk (_.map randomSelection, (i) -> "/r/#{i}"), 2
							resize_keyboard: true
							one_time_keyboard: true


				when "Search"
					@sendChatAction "typing"
					searchYoutube.call @, arg1
					@mode = ""

				when "SettingsStart"
					@sendMessage Messages.SettingsStart()
					@mode = "settings"

	# Send songs found from searching YouTube
	sendYoutubeSelection: () ->
		_.forEach @youtubeSongs, (item, i) =>
			item.i = i + 1;
			@sendMessage Messages.YoutubeResult item
		@mode = "youtubeselection"
		setTimeout () =>
			keyboard = _.chunk _.map @youtubeSongs, (i) -> "#{i.snippet.title}"
			keyboard.push "/cancel"
			@sendMessage Messages.YoutubeDownload(@youtubeSongs),
				reply_markup: JSON.stringify
					keyboard: keyboard
					resize_keyboard: true
					one_time_keyboard: true
		, 500

	# Send a message to the chat
	#
	# @param [String] text Text message to send
	# @param [Object] options Additional message options
	#
	# @see https://core.telegram.org/bots/api#sendmessage
	sendMessage: (text, options) ->
		if options?
			@bot.sendMessage @id, text, options
		else
			@bot.sendMessage @id, text

	# Send a chat action
	#
	# @param [String] action Type of action to broadcast.
	# Choose one, depending on what the user is about to receive:
	# typing for text messages,
	# upload_photo for photos,
	# record_video or upload_video for videos,
	# record_audio or upload_audio for audio files,
	# upload_document for general files,
	# find_location for location data.
	sendChatAction: (action) ->
		@bot.sendChatAction @id, action

	# Send an audio file
	#
	# @param [String] audio File path to the audio file
	# @param [String] caption An included caption
	sendAudio: (audio, caption) ->
		@bot.sendAudio @id, audio, {caption: caption}

	# Send a random cat fact
	sendRandom: () ->
		catEmojis = ["😺", "😸", "😻", "😽", "😼", "🙀", "😿", "😹", "😾"]
		catEmoji = catEmojis[Math.floor(Math.random() * catEmojis.length)]
		switch (Math.round Math.random() * 2)
			when 1
				console.log "cat facts!"
				request.get "https://catfacts-api.appspot.com/api/facts", (err, resp, body) =>
					@sendMessage catEmoji + _.first(JSON.parse(body).facts)


module.exports = Chat
