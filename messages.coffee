_ = require "lodash"

# /get - 💾 📲 \n
# /reddit - 🔍 Reddit 🎶 \n

module.exports = 
	Greet: _.template "
		Hey <%= user %>, I'm here to help you find and listen to great music 🎵 I'm the bot for www.musicplayer.io
		\n
		\nYou can /search for songs on Youtube.
		\nOr you can look up a /reddit subreddit
		\n
		\nWhat do you wanna do?
	"
	Help: _.template "
		Hey <%= user %>, I'm here to help you find and listen to great music 🎵
		\n
		\nIf you have some feedback, let me know @illyism 🍺
		\n
		\n/search
		\nSearches music on Youtube and lists a few options.
		\nYou can type '/search <my favourite artist>' instead of going through my questions.
		\n
		\n/reddit
		\nSearches for music links on a subreddit.
		\nYou can type '/r/listentothis' or any other sub to search immediately.
	"
	Commands: _.template "
		/search
		\nSearches music on Youtube and lists a few options.
		\nYou can type '/search <my favourite artist>' instead of going through my questions.
		\n
		\n/reddit
		\nSearches for music links on a subreddit.
		\nYou can type '/r/listentothis' or any other sub to search immediately.
	"
	Undefined: _.template "
		Sorry, <%= user %> 💩
		\nI didn't recognize your message.
	"
	SearchStart: _.template "
		What do you want to listen to?
	"
	YoutubeEmpty: _.template "
		You should add a Youtube ID.
	"
	YoutubeResult: _.template "
		http://www.youtube.com/watch?v=<%= id.videoId %>
		\n\n Download 🎵 /<%=i%>
	"
	YoutubeStarted: _.template "
		Let's see...\n
		\nFilename: <%= _filename %>
		\nSize: <%= Math.round(size / 1000000) %>MB
		
	"
	YoutubeDone: _.template "
		Downloaded 👌 Let me convert and send that to you you 💤
	"
	YoutubeDownload: _.template "
		Which of these <%= length %> do you want to listen to?
		\nOr you can /cancel instead.
	"

	YoutubeTooLarge: _.template "
		That file is too large for me to send 😭
		\nhttp://www.youtube.com/watch?v=<%= id %>
	"
	RedditStart: _.template "
		What subreddit do you want to listen to? Here's a 🎲 selection of a few:
		\n<% _.forEach(subs, function(sub) {%>/r_<%=sub%>\n<% }) %>
	"
	Reddit: _.template "
		Looking for music on /r/<%= sub %>
	"
	RedditList: _.template "
		Here are <%= list.length %> links I've found in /r/<%=sub%>
	"
	RedditLink: _.template "
		<%= title %>
		\n<%= score %> 💕 / 👤 <%= author %>
		\n<%= url %>\n
		<% if (id) { %>\n💾 /youtube_<%= id %><% } %>
	"
	RedditEmpty: _.template "
		Didn't find anything that looks like a song 😥
	"
	Error: _.template "
		CRITICAL MALFUNCTION 🐷
		\nTry again?
	"
	Ok: _.template "
		👍
	"
	Wait: _.template "
		⏳
	"