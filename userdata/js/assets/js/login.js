const login = {
	data() {
		return {
			//api_server_address: '',
			sw: 0,	
			username: '',
			password: '',
			msg: '',
			name: '',
			apikey: '',
			//is_admin: false,
			//api_server_address: '129.159.119.35',
			output: '',
		}
	},
	async created(){
		this.get_identity();
	},
	methods: {
		get_identity: async function(){
			var that = this;
			requestOptions = {
                method: "GET",
                headers: { "Content-Type": "application/json", },
            };
			var status_code;
			const response = await fetch('/api/v1/users/identity', requestOptions)
			.then(function (response) {
				if (!response.ok){
					status_code = 400;
					var res = response.json();
					if(res)
						return res;
					else
						return { "error": "Error. Please try again later" }; 
				}
				else{
					return response.json();
				}
			});
			if(status_code != 400){
				window.location.replace("transcodingOKE.html");
			}
				
		},
		login: async function(){
			this.msg = '';
			var that = this;
			requestOptions = {
                method: "POST",
                headers: { "Content-Type": "application/json"},
				body: JSON.stringify({
					"email": this.username,
					"password": this.password,
                }),
            };
			var status_code;
			const response = await fetch('/api/v1/login', requestOptions)
			.then(function (response) {
				if (!response.ok){
					status_code = 400;
					var res = response.json();
					if(res)
						return res;
					else
						return { "error": "Error. Please try again later" }; 
				}
				else{
					return response.json();
				}
			});
			if(status_code == 400)
				this.msg = response.error;	
			else
				window.location.replace("transcodingOKE.html");
		},
		register: async function(){
			this.msg = '';
			var that = this;
			requestOptions = {
                method: "POST",
                headers: { "Content-Type": "application/json"},
				body: JSON.stringify({
					"name": this.name,
    				"email": this.username,
    				"password": this.password,
    				//"is_admin": this.is_admin,
                }),
            };
			var status_code;
			const response = await fetch('/api/v1/register', requestOptions)
			.then(function (response) {
				if (!response.ok){
					status_code = 400;
					var res = response.json();
					if(res)
						return res;
					else
						return { "error": "Error. Please try again later" }; 
				}
				else{
					that.username = '';
					that.name = '';
					//that.is_admin = false;
					that.password = '';
					return response.json();
				}
			});
			if(status_code == 400)
				this.msg = response.error;	
			else{
				this.msg = 'Request for approval submitted';
				this.switch_tabs();
			}
		},
		forgot_password: async function(){
			this.msg = '';
			var that = this;
			requestOptions = {
                method: "POST",
                headers: { "Content-Type": "application/json"},
				body: JSON.stringify({
    				"email": this.username,
    				"api_key": this.apikey,
    				"password": this.password,
                }),
            };
			const response = await fetch('/api/v1/reset_password', requestOptions)
			.then(function (response) {
				if (!response.ok){
					status_code = 400;
					var res = response.json();
					if(res)
						return res;
					else
						return { "error": "Error. Please try again later" }; 
				}
				else{
					status_code = 200;
					return response.json();
				}
			});
			if(status_code == 400)
				this.msg = response.error;	
			else{
				this.username = '';
				this.apikey = '';
				this.password = '';
				this.msg = 'Password Reset Successful!';
				this.switch_tabs();
			}
		},
		switch_tabs: function(){
			if(this.sw == 0)
				this.sw = 1;
			else if(this.sw == 1)
				this.sw = 0;
			else if(this.sw == 2)
				this.sw = 0;
			else
				this.sw = 2;
			this.username = '';
			this.password = '';
			this.apikey = '';
			this.msg = '';
			this.name = '';
		},
	},
	computed: {
		isDisabled: function(){
			if(this.username.length > 0 && /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,32}$/.test(this.password))
				return false;
			return true;
			//return false;
		},
		isDisabled2: function () {
			if(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,32}$/.test(this.password) && /^([a-zA-Z0-9_\-\.]+)@([a-zA-Z0-9_\-\.]+)\.([a-zA-Z]{2,5})$/.test(this.username))
				return false;
			return true;
			//return false;
        },
		isDisabled3: function(){
			if(this.apikey.length > 16 && this.username.length > 0 && /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,32}$/.test(this.password))
				return false;
			return true;
			//return false;
		},
	}
}

const app = Vue.createApp(login).mount('#login_section');
