import crypto from 'crypto'
import path from 'path'
import fs from 'fs'
import os from 'os'

import { nanoid, customAlphabet } from 'nanoid'
import cheerio from 'cheerio'

import {TEMPLATE_DIR, TriggerNoCardsError, TriggerUnsupportedFormat} from '../constants'
import CardGenerator from '../service/generator'

String.prototype.replaceAll = do |oldValue, newValue|
	console.log('replaceAll', oldValue, newValue)
	unless oldValue != newValue
		return this
	let temp = this
	let index = temp.indexOf(oldValue)
	while index != -1
		temp = temp.replace(oldValue, newValue)
		index = temp.indexOf(oldValue)
	return temp

class CustomExporter

	prop first_deck_name
	prop workspace
	prop media

	def constructor first_deck_name, workspace
		self.first_deck_name = first_deck_name.replace('.html', '')
		self.workspace = workspace
		self.media ||= []

	def addMedia newName, file
		const abs = path.join(self.workspace, newName)
		self.media.push(abs)
		fs.writeFileSync(abs, file)

	def addCard back, tags
		console.log('addCard', arguments)

	def configure payload
		const payload_info = path.join(self.workspace, 'deck_info.json')
		console.log('writing payload', payload_info)
		fs.writeFileSync(payload_info, JSON.stringify(payload, null, 2))

	def save
		const gen = new CardGenerator(self.workspace)
		const payload = await gen.run()
		return fs.readFileSync(payload)

export class DeckParser

	get name do self.payload[0].name

	def constructor file_name, settings = {}, files
		const deckName = settings.deckName
		const contents = files[file_name]
		self.settings = settings
		self.settings['font-size'] = self.settings['font-size'] + 'px'
		self.use_input = self.enable_input!
		self.use_cloze = self.is_cloze!
		self.image = null
		self.files = files || []
		self.first_deck_name = file_name
		self.payload = handleHTML(contents, deckName)

	def handleHTML contents, deckName = null, decks = []
		const dom = cheerio.load(contents)
		let name = deckName || dom('title').text()
		console.log("Title: " + dom('title').text())
		let style = dom('style').html()
		style = style.replace(/white-space: pre-wrap;/g, '')
		let image = null

		if self.settings['font-size'] != '20px'
			style += '\n' + '* { font-size:' + self.settings['font-size'] + '}'

		let pageCoverImage = dom('.page-cover-image')
		if pageCoverImage
			image = pageCoverImage.attr('src')


		var toggleList = dom("div[class=column-list]").toArray()
		toggleList = toggleList.map do |t|
			const elements = dom(t).find('figure.callout').length
			if elements == 0
				return t
			else
				return null
		toggleList = toggleList.filter(Boolean)
		console.log(toggleList.length)

		let cards = toggleList.map do |t|
			// We want to perserve the parent's style, so getting the class
			const columnList = dom(t)
			const parentClass = dom(t).attr("class")

			const toggleMode = self.settings['toggle-mode']
			if toggleMode == 'open_toggle'
				dom('details').attr('open', '')
			elif toggleMode == 'close_toggle'
				dom('details').removeAttr('open')

			if columnList
				dom('details').addClass(parentClass)
				dom('summary').addClass(parentClass)
				const summary = columnList.find('div').first()
				const toggle = columnList.find("details").first()
				if summary
					let toggleHTML = toggle.html()
					let summaryHTML = summary.html()
					if dom(summary).find('li').length == 1
						summaryHTML = dom(summary).find('li').first().html()
					console.log(dom(summary).find('li').first().html())
					if dom(toggle).find('li').length == 1
						toggleHTML = dom(toggle).find('li').first().html()

					console.log("Summary: " + summaryHTML)
					const note = { name: summaryHTML, back: toggleHTML.replace(summary, "") }
					const cherry = '&#x1F352;' # 🍒
					if settings['cherry'] and !note.name.includes(cherry) and !note.back.includes(cherry)
						return null
					else
						return note
		# Prevent bad cards from leaking out
		cards = cards.filter(Boolean)
		console.log('cards', cards)
		cards = sanityCheck(cards)

		decks.push({name: name, cards: cards, image: image, style: style, id: self.generate_id!})

		# unless cards.length > 0
		# 	TriggerNoCardsError()
		const subpages = dom(".link-to-page").toArray()
		for page in subpages
			const spDom = dom(page)
			const ref = spDom.find('a').first()
			const href = ref.attr('href')
			const pageContent = self.files[global.decodeURIComponent(href)]
			if pageContent
				const subDeckName = spDom.find('title').text() || ref.text()
				self.handleHTML(pageContent, "{name}::{subDeckName}", decks)

		return decks

	def has_cloze_deletions input
		return false if !input

		input.includes('code')

	def valid_input_card input
		return false if !self.enable_input()
		input.name and input.name.includes('strong')

	def sanityCheck cards
		let empty = cards.find do |x|
			if !x
				console.log 'broken card'
			if !x.name
				console.log('card is missing name')
			if !x.back
				console.log('card is missing back')
				return has_cloze_deletions(x.name)
			!x  or !x.name or !x.back
		if empty
			console.log('warn Detected empty card, please report bug to developer with an example')
			console.log('cards', cards)
		cards.filter do |c|
			c.name and (has_cloze_deletions(c.name) or c.back or valid_input_card(c))

	// Try to avoid name conflicts and invalid characters by hashing
	def newUniqueFileName input
		var shasum = crypto.createHash('sha1')
		shasum.update(input)
		shasum.digest('hex')

	def suffix input
		return null if !input

		const m = input.match(/\.[0-9a-z]+$/i)
		return null if !m

		return m[0] if m

	def setupExporter deck, workspace
		const css = deck.style.replaceAll("'", '"')
		fs.mkdirSync(workspace)
		fs.writeFileSync(path.join(workspace, 'deck_style.css'), css)
		return new CustomExporter(self.first_deck_name, workspace)

	def embedFile exporter, files, filePath
		# console.log('embedFile', Object.keys(files), filePath)
		const suffix = self.suffix(filePath)
		return null if !suffix
		let file = files["{filePath}"]
		if !file
			file = files["{exporter.first_deck_name}/{filePath}"]
			if !file
				throw new Error("Missing relative path to {filePath} used {exporter.first_deck_name}")
		const newName = self.newUniqueFileName(filePath) + suffix
		exporter.addMedia(newName, file)
		return newName

	# https://stackoverflow.com/questions/6903823/regex-for-youtube-id
	def get_youtube_id input
		# console.log('get_youtube_id', arguments)
		try
			const m =  input.match(/(?:youtu\.be\/|youtube\.com(?:\/embed\/|\/v\/|\/watch\?v=|\/user\/\S+|\/ytscreeningroom\?v=|\/sandalsResorts#\w\/\w\/.*\/))([^\/&]{10,12})/)
			# prevent swallowing of soundcloud embeds
			if m[0].match(/https:\/\/soundcloud.com/)
				return null
			return m[1]
		catch error
				return null

	def get_soundcloud_url input
		# console.log('get_soundcloud_url', arguments)
		try
			const sre = /https?:\/\/soundcloud\.com\/\S*/gi
			return input.match(sre)[0].split('">')[0]
		catch error
			return null

	def find_mp3_file input
		try
			const m = input.match(/<a\s+(?:[^>]*?\s+)?href=(["'])(.*?)\1/i)[2]
			unless m.endsWith('.mp3') and !m.startsWith('http')
				return null
			return m
		catch error
			return null

	def handleClozeDeletions input
		const dom = cheerio.load(input)
		const clozeDeletions = dom('code')
		let mangle = input

		clozeDeletions.each do |i, elem|
			const v = dom(elem).html()
			const old = "<code>{v}</code>"
			const newValue = '{{c'+(i+1)+'::'+v+'}}'
			mangle = mangle.replaceAll(old, newValue)
		mangle

	def treatBoldAsInput input, inline=false
		const dom = cheerio.load(input)
		const underlines = dom('strong')
		let mangle = input
		let answer = ''
		underlines.each do |i, elem|
			const v = dom(elem).html()
			const old = "<strong>{v}</strong>"
			mangle = mangle.replaceAll(old, inline ? v : '{{type:Input}}')
			answer = v
		{mangle: mangle, answer: answer}

	def is_cloze
		self.settings['cloze']

	def enable_input
		self.settings['enable-input']

	def generate_id
		return parseInt(customAlphabet('1234567890', 16)())

	def locate_tags card
		let input = [card.name, card.back]

		for i in input
			continue if not i

			const dom = cheerio.load(i)
			const deletions = dom('del')

			deletions.each do |i, elem|
				const del = dom(elem)
				card.tags = del.text().split(',').map do $1.trim().replace(/\s/g, '-')
				card.back = card.back.replaceAll(del.html(), '')
				card.name = card.name.replaceAll(del.html(), '')
		return card

	def build
		console.log('building deck')
		const workspace = path.join(os.tmpdir(), nanoid())
		let exporter = self.setupExporter(self.payload[0], workspace)

		for deck in self.payload
			const card_count = deck.cards.length
			deck.image_count = 0

			deck.card_count = card_count
			deck.id = self.generate_id!
			console.log('set deck id', deck.id)
			delete deck.style

			# Counter for perserving the order in Anki deck.
			let counter = 0
			const addThese = []
			for card in deck.cards
				console.log("exporting {deck.name} {deck.cards.indexOf(card)} / {card_count}")
				card['enable-input'] = self.settings['enable-input'] || false
				card.number = counter++
				if self.use_cloze
					card.name = self.handleClozeDeletions(card.name)
				if self.use_input && card.name.includes('<strong>')
					let inputInfo = self.treatBoldAsInput(card.name)
					card.name = inputInfo.mangle
					card.answer = inputInfo.answer

				card.media = []
				if card.back
					const dom = cheerio.load(card.back)
					const images = dom('img')
					if images.length > 0
						console.log('Number of images', images.length)
						images.each do |i, elem|
							const originalName = dom(elem).attr('src')
							if !originalName.startsWith('http')
								if let newName = self.embedFile(exporter, self.files, global.decodeURIComponent(originalName))
									dom(elem).attr('src', newName)
									card.media.push(newName)
						deck.image_count += (card.back.match(/\<+\s?img/g) || []).length
						card.back = dom.html()

					if let audiofile = find_mp3_file(card.back)
						if let newFileName = self.embedFile(exporter, self.files, global.decodeURIComponent(audiofile))
							console.log('added sound', newFileName)
							card.back += "[sound:{newFileName}]"
							card.media.push(newFileName)

					# Check YouTube
					if let id = get_youtube_id(card.back)
						const ytSrc = "https://www.youtube.com/embed/{id}?".replace(/"/, '')
						const video = "<iframe width='560' height='315' src='{ytSrc}' frameborder='0' allowfullscreen></iframe>"
						card.back += video
					if let soundCloudUrl = get_soundcloud_url(card.back)
						const audio = "<iframe width='100%' height='166' scrolling='no' frameborder='no' src='https://w.soundcloud.com/player/?url={soundCloudUrl}'></iframe>"
						card.back += audio

					console.log('xparse back', self.use_input)
					if self.use_cloze
						# TODO: investigate why cloze deletions are not handled properly on the back / extra
						card.back = self.handleClozeDeletions(card.back)
					if self.use_input and card.back.includes('<strong>')
						let inputInfo = self.treatBoldAsInput(card.back, true)
						card.back = inputInfo.mangle

				card.tags ||= []
				if self.settings['tags']
					card = self.locate_tags(card)

				if self.settings['basic-reversed']
						addThese.push({name: card.back, back: card.name, tags: card.tags, media: card.media, number: counter++})
				if self.settings['reversed']
					const tmp = card.back
					card.back = card.name
					card.name = tmp
			deck.cards = deck.cards.concat(addThese)
		exporter.configure(self.payload)
		exporter.save()

export def PrepareDeck file_name, files, settings
		const parser = new DeckParser(file_name, settings, files)
		const apkg = await parser.build()
		# TODO: rename decks below to something more sensible
		{name: "{parser.name}.apkg", apkg: apkg, deck: parser.payload}
