import React from 'react'

export default class LoginModal extends React.Component {
	constructor(props) {
		super(props)
		this.state = {
			username: '',
			password: '',
			server: this.props.chatServer || '',
		}
	}
	submit = e => {
		e.preventDefault()

		if (
			this.state.server === null ||
			this.state.server === undefined ||
			this.state.server.length < 1 ||
			this.state.username === null ||
			this.state.username === undefined ||
			this.state.username.length < 1 ||
			this.state.password === null ||
			this.state.password === undefined ||
			this.state.password.length < 1
		)
			return

		this.props.updateServer(this.state.server)

		let formData = new FormData()
		formData.append('username', this.state.username)
		formData.append('password', this.state.password)

		fetch(this.state.server + '/login', {
			method: 'POST',
			body: formData,
		})
			.then(res => {
				return new Promise((resolve, reject) => {
					res
						.json()
						.then(json =>
							resolve({
								status: res.status,
								ok: res.ok,
								json,
							})
						)
						.catch(error =>
							resolve({
								status: res.status,
								ok: res.ok,
								json: {
									message:
										res.status === 403
											? 'Invalid username or password'
											: `${res.status}: ${res.statusText}\nUnable to login`,
								},
							})
						)
				})
			})
			.then(res => {
				if (res.ok) this.props.updateToken(res.json.token)
				else return Promise.reject(res.json)
			})
			.catch(error => {
				alert(error.message)
			})
	}

	render() {
		return (
			<div id="login-modal">
				<div className="content">
					<h2 id="login-modal-header">Login</h2>
					<form onSubmit={this.submit}>
						<div>
							<label>
								Chat URL
								<br />
								<input
									id="url"
									className="textinput"
									type="text"
									onChange={e =>
										this.setState({
											server: e.target.value,
										})
									}
									value={this.state.server}
								/>
							</label>
						</div>
						<br />
						<div>
							<label>
								Username
								<br />
								<input
									id="username"
									className="textinput"
									type="text"
									onChange={e =>
										this.setState({
											username: e.target.value,
										})
									}
									value={this.state.username}
								/>
							</label>
						</div>
						<div>
							<label>
								Password
								<br />
								<input
									id="password"
									className="textinput"
									size={40}
									type="password"
									onChange={e =>
										this.setState({
											password: e.target.value,
										})
									}
									value={this.state.password}
								/>
							</label>
						</div>
						<br />
						<br />
						<input className="submit" type="submit" value="Login" />
					</form>
				</div>
			</div>
		)
	}
}
