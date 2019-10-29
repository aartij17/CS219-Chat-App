import React from 'react'
// import logo from './logo.svg';
import './App.css'
import LoginModal from './LoginModal'
import Container from './Container'

class App extends React.Component {
	constructor(props) {
		super(props)

		this.state = {
			server: this.props.chatServer,
		}
	}

	updateToken = token => {
		this.setState({ token })
	}

	updateServer = server => {
		this.setState({ server })
	}

	render() {
		return (
			<div className="App">
				{!this.state.token && (
					/*login modal*/
					<LoginModal
						updateToken={this.updateToken}
						updateServer={this.updateServer}
						{...this.props}
					/>
				)}

				{/*container*/}
				<Container updateToken={this.updateToken} {...this.state} />
			</div>
		)
	}
}

export default App
