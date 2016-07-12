function pretendRequest(email, pass, cb) {
	setTimeout(() => {
		if (email === 'user@sendence.com' && pass === 'sendence1') {
			cb({
				authenticated: true,
				token: Math.random().toString(36).substring(7)
			})
		} else {
			cb({ authenticated: false })
		}
	}, 0)
}

module.exports = {
	login(email, pass, cb) {
		if (localStorage.token) {
			if (cb) cb(true)
			this.onChange(true)
			return
		}
		pretendRequest(email, pass, (res) => {
			if (res.authenticated) {
				localStorage.token = res.token
				if (cb) cb(true)
				this.onChange(true)
			} else {
				if (cb) cb(false)
				this.onChange(false)
			}
		})
	},

	getToken() {
		return localStorage.token
	},

	logout(cb) {
		delete localStorage.token
		if (cb) cb()
		this.onChange(false)
	},

	loggedIn() {
		return !!localStorage.token
	},

	onChange() {}
}