import React from 'react'

export default class UsersList extends React.Component {
	constructor(props) {
		super(props)
		this.state = {}
	}

	render() {
		return (
			<div id="user_window">
				<h2 className={this.props.connected ? 'connected' : 'disconnected'}>
					Online
				</h2>
				<ul id="users">
					{this.props.users &&
						Array.from(this.props.users).map(element => (
							<li key={element}>{element}</li>
						))}
				</ul>
			</div>
		)
	}
}
