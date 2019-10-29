import React from 'react'

import UsersList from './UsersList'
import MessageList from './MessageList'
import Compose from './Compose'

export default class Container extends React.Component {
	constructor(props) {
		super(props)
		this.state = {
			messages: [],
			connected: false,
		}
	}

	componentDidUpdate = prevProps => {
		if (this.props.token !== prevProps.token && !prevProps.token) {
			this.startStream()
		}
	}

	date_format = timestamp => {
		var date = new Date(timestamp * 1000)
		return (
			date.toLocaleDateString('en-US') + ' ' + date.toLocaleTimeString('en-US')
		)
	}

	startStream = () => {
		let source = new EventSource(
			this.props.server + '/stream/' + this.props.token
		)

		source.addEventListener(
			'Users',
			event => {
				let data = JSON.parse(event.data)
				this.setState({
					users: new Set(data.users),
					connected: true,
					messages: [],
				})
			},
			false
		)

		source.addEventListener(
			'Join',
			event => {
				let data = JSON.parse(event.data)
				let newMessage = `${this.date_format(data.created)} JOIN: ${data.user}`
				this.setState(prevState => ({
					users: prevState.users.add(data.user),
					messages: [...prevState.messages, newMessage],
					connected: true,
				}))
			},
			false
		)

		source.addEventListener(
			'Part',
			event => {
				let data = JSON.parse(event.data)
				let newMessage = `${this.date_format(data.created)} PART: ${data.user}`
				this.setState(prevState => ({
					users: prevState.users.delete(data.user)
						? prevState.users
						: prevState.users,
					messages: [...prevState.messages, newMessage],
					connected: true,
				}))
			},
			false
		)

		source.addEventListener(
			'Disconnect',
			event => {
				source.close()
				this.props.updateToken(undefined)
				this.setState({ users: undefined, connected: false })
			},
			false
		)

		source.addEventListener(
			'Message',
			event => {
				let data = JSON.parse(event.data)
				let newMessage = `${this.date_format(data.created)} (${data.user})\
					${data.message}`
				this.setState(prevState => ({
					messages: [...prevState.messages, newMessage],
					connected: true,
				}))
			},
			false
		)

		source.addEventListener(
			'ServerStatus',
			event => {
				let data = JSON.parse(event.data)
				let newMessage = `${this.date_format(data.created)} STATUS:\
					${data.status}`
				this.setState(prevState => ({
					messages: [...prevState.messages, newMessage],
					connected: true,
				}))
			},
			false
		)

		source.addEventListener(
			'error',
			event => {
				if (event.target.readyState === 2) {
					this.props.updateToken(undefined)
					this.setState({ users: undefined, connected: false })
				} else {
					console.log('Disconnected, retrying')
					this.setState({ connected: false })
				}
			},
			false
		)
	}

	render() {
		return (
			<section id="container">
				<div id="title">
					<h1
						className={
							this.props.token && this.state.connected
								? 'connected'
								: 'disconnected'
						}
					>
						CS291A Chat System
					</h1>
				</div>

				<div id="window">
					{/*messages tree*/}
					<MessageList messages={this.state.messages} />
					{/*users modal*/}
					<UsersList
						connected={
							this.props.token !== null &&
							this.props.token !== undefined &&
							this.state.connected
						}
						users={this.state.users}
					/>
				</div>
				{/*typing prompt window*/}
				<Compose connected={this.state.connected} {...this.props} />
			</section>
		)
	}
}
