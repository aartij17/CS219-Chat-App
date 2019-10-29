import React from 'react'
import ReactDOM from 'react-dom'
import './index.css'
import App from './App'

// const CHATSERVER = 'http://chat.cs291.com'
const CHATSERVER = 'http://localhost:8000'

console.log(" CCC  SSS   22   9999  11   AA       CCC H  H  AA  TTTTTT\n\
C    S     2  2 9   9 111  A  A     C    H  H A  A   TT\n\
C     SSS    2   9999  11  AAAA     C    HHHH AAAA   TT\n\
C        S  2      9   11  A  A     C    H  H A  A   TT\n\
 CCC SSSS  2222   9   11l1 A  A      CCC H  H A  A   TT\n")

ReactDOM.render(
	<App chatServer={CHATSERVER} />,
	document.getElementById('root')
)
