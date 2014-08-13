github-pages-search
====================

This is a proof-of-concept Sinatra server for implementing search for GitHub Pages. It's meant to be implemented as a webhook that waits for [a `PageBuild` event](https://developer.github.com/v3/activity/events/types/#pagebuildevent). 

There are many potential improvements to be made. For one, instead of cloning the whole repository down, we could check for a sitemap.xml file at root, or otherwise crawl over all the pages. But like I said: proof-of-concept. 
