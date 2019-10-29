import React from 'react'

export default class Compose extends React.Component {
	constructor(props) {
		super(props)
		this.state = {
			message: 'Please connect to send messages',
		}
	}

	componentDidUpdate = prevProps => {
		if (this.props.token !== prevProps.token && !prevProps.token)
			this.setState({ message: '' })

		if (this.props.token !== prevProps.token && !this.props.token)
			this.setState({ message: 'Please connect to send messages' })

		if (this.props.connected !== prevProps.connected && !this.props.connected)
			this.setState({ message: 'Please connect to send messages' })

		if (this.props.connected !== prevProps.connected && !prevProps.connected)
			this.setState({ message: '' })
	}

	submit = e => {
		e.preventDefault()

		if (
			this.state.message === null ||
			this.state.message === undefined ||
			this.state.message.length < 1
		)
			return
		let formData = new FormData()
		formData.append('message', this.state.message)

		fetch(this.props.server + '/message', {
			method: 'POST',
			body: formData,
			headers: { Authorization: `Bearer ${this.props.token}` },
		})
			.then(res => {
				if (res.ok) this.setState({ message: '' })
				else
					return new Promise((resolve, reject) => {
						res
							.json()
							.then(json =>
								reject({
									message: json.message,
								})
							)
							.catch(error =>
								reject({
									message: `${res.status}: ${res.statusText}\nUnable to send message`,
								})
							)
					})
			})
			.catch(error => {
				alert(error.message)
			})
	}

	render() {
		return (
			<div id="compose_window">
				<form onSubmit={this.submit}>
					<input type="submit" value="Send" />
					<div id="message_div">
						<input
							type="text"
							id="message"
							value={this.state.message}
							onChange={e => this.setState({ message: e.target.value })}
							disabled={this.props.token && this.props.connected ? false : true}
						/>
					</div>
				</form>
			</div>
		)
	}
}
