_ = require "lodash"

# Command
#
# @property [RegExp] regex Regular expression to parse with
# @property [String] type The type of Command
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
	Player:
		regex: /\/player\s?(.*)/gm
		type: "Player"
	PlayerStart:
		type: "PlayerStart"
	Settings:
		regex: /\/settings\s?(.*)/gm
		type: "Settings"
	SettingsStart:
		type: "SettingsStart"
	RedditStart:
		type: "RedditStart"

# Parses a message and returns a Command
#
# @param [String] msg The message to parse
# @param [Function] cb The function to execute
module.exports = (msg, cb) ->
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
	else if msg.match Commands.Settings.regex
		matches = Commands.Settings.regex.exec msg
		if matches[1]
			cb Commands.Settings, matches[1]
		else
			cb Commands.SettingsStart
	else if msg.match Commands.Player.regex
		matches = Commands.Player.regex.exec msg
		if matches[1]
			cb Commands.Player, matches[1]
		else
			cb Commands.PlayerStart
	else
		cb Commands.Undefined

module.exports.Commands = Commands
