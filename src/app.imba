# Components
import './pages/upload-page'
import './pages/privacy-page'
import './components/n2a-footer'

tag app-root
	prop state = 'ready'
	# TODO: expose more card template stuff
	prop settings = {'font-size': 20}

	css .rounded border: 0.1px solid white br: 0.25rem td: none  p: 0.1rem 2 my: 2 c: white mr: 4 bg: none  	


	def page
		window.location.pathname

	def mount
		window.onbeforeunload = do
			if state != 'ready'
				return "Conversion in progress. Are you sure you want to stop it?"				
	def render
		<self>
			if page().includes('privacy')
				<privacy-page>
			else
				<upload-page state=state progress=progress>
			<n2a-footer>
