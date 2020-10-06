import './youtube-embed'

tag download-modal

	prop title = "Modal title"
	prop showModal = true
	prop downloadLink = null
	prop deckName

	def pressedIcon
		showModal = true

	get navigator do window.navigator
	

	def patreonIntro
		'https://www.youtube.com/embed/EoB_zj7jeEk'
	
	def patreonIntroTitle
		"Patreon Intro 🧡"		

	<self[d: flex fld: column]>
		if showModal
			<.modal[d: flex]>
				<.modal-background>
				<.modal-card>
					<header.modal-card-head>
						<p.modal-card-title> title
						<button.delete aria-label="close" @click.{showModal=false}>
					<section.modal-card-body>
						<.has-text-centered>
							<a[m: 2rem].button.is-primary href=downloadLink @click.didDownload download=deckName> "Click to Download"