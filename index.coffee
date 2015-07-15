TelegramBot = require "node-telegram-bot-api"
config = require "./config.json"
token = config.token

_ = require "lodash"
_.mixin
	# Make an Array or String lowercase
	lower: (o) ->
		return o.toLowerCase() if _.isString(o)
		_.map o, (s) ->
			if _.isString(s) then s.toLowerCase() else s

Chat = require "./chat"
Messages = require "./messages"

bot = new TelegramBot token, {polling: true}
chats = []

bot.getMe().then (me) -> console.log me
bot.on "message", (msg) ->
	chat = _.find chats, (c) -> c.id is msg.chat.id

	# Ignore all non-text messages
	if not msg.text?
		msg.text = "/start"

	# Send a message to the existing chat
	if chat?
		chat.emit "message", msg.text

	# Create a new Chat and send the message
	else
		chats.push new Chat bot, msg.chat, msg.text


exports.Chat = Chat
