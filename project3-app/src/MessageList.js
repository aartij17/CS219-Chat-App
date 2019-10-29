import React from 'react'

export default class MessageList extends React.Component {
	constructor(props) {
		super(props)
		this.state = {}
	}

	componentDidMount() {
		this.messagesEnd.scrollIntoView({ behavior: 'smooth' })
	}

	componentDidUpdate() {
		this.messagesEnd.scrollIntoView({ behavior: 'smooth' })
	}

	render() {
		return (
			<div id="chat">
				{this.props.messages &&
					this.props.messages.map((element, index) => (
						<div key={index}>{element}</div>
					))}
				<div
					style={{ float: 'left', clear: 'both' }}
					ref={el => {
						this.messagesEnd = el
					}}
				/>
			</div>
		)
	}
}
