_ = require "lodash"

# /get - 💾 📲 \n
# /reddit - 🔍 Reddit 🎶 \n

module.exports = 
	Greet: _.template "
		Hey <%= user %>! I'm a bot that helps you 🔍, ▶ and 💾 🎵. Feel free to say /help if you need any! ❤
	"
	Help: _.template "
		Hey <%= user %>! I'm a bot that helps you 🔍, ▶ and 💾 🎵.
		\n\n
		/search - 🔍 🎶 \n
	"
	Commands: _.template "
		/search - 🔍 🎶 \n
		/help - ❓
	"
	Undefined: _.template "
		Sorry, <%= user %> 👎\n
		I didn't recognize your message.
	"
	SearchStart: _.template "
		What do you want to listen to?
	"
	YoutubeEmpty: _.template "
		You should add a Youtube ID.
	"
	YoutubeResult: _.template "
		<%= snippet.title %> \n
		Channel: <%= snippet.channelTitle %>\n
		Date: <%= new Date(snippet.publishedAt).toLocaleDateString() %>\n
		\n
		/<%=i%>
	"
	YoutubeStarted: _.template "
		Filename: <%= _filename %>\n
		Size: <%= Math.round(size / 1000000) %>MB\n
		⏳
	"
	YoutubeDone: _.template "
		Downloaded and converted! Let me send that to you...
	"
	YoutubeDownload: _.template """
		Which of these <%= length %> do you want to listen to?\n
		Or do you want to /cancel
	"""
	Error: _.template "
		CRITICAL MALFUNCTION 🐷\n
		Try again?
	"
	Ok: _.template "
		👍
	"
	Wait: _.template "
		⏳
	"