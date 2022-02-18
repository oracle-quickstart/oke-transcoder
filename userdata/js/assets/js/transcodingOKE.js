const project = {
	data() {
		return {
			projects: '',
			jobs: '',
			filtered_jobs: '',
			selected_project: '',
			jobs_filter_status: [true,true,true],
			number_jobs_running: 0,
			number_jobs_completed: 0,
			number_jobs_error: 0,
			number_transcoded_videos: 0,

			new_project_name: '',
			new_src_bucket: '',
			new_dst_bucket: '',
			advanced: false,
			number_of_streams: 3,
			codec: 'libx264 -sc_threshold 0',
			seg_dur: 5,
			gop_size: 48,
			protocol: 'hls',
			selected_video_resolution: ['1920x1080', '1280x720', '640x360', '640x360', '640x360', '640x360', '640x360', '640x360', '640x360', '640x360'],
            selected_video_bitrate : [5, 3, 1, 1, 1, 1, 1, 1, 1, 1],
            selected_video_bitrate_minimum : [5, 3, 1, 1, 1, 1, 1, 1, 1, 1],
            selected_video_bitrate_maximum : [5, 3, 1, 1, 1, 1, 1, 1, 1, 1],
            selected_buffer_size : [10, 3, 1, 1, 1, 1, 1, 1, 1, 1],
		}
	},
	async mounted() {
		/*this.thumbnails = response.objects.filter(x => x['name'].substring(0, 11) === 'thumbnails/');
		this.poster = this.base_end_point + this.thumbnails[0].name;

		this.playlist = response.objects.filter(x => x['name'].substring(x['name'].length - 11) === 'master.m3u8');
		this.source = this.base_end_point + this.playlist[0].name;*/

		requestOptions = {
			method: "GET",
			headers: { "Content-Type": "application/json", },//"Authorization": "Basic " + btoa(userName + ":" + passWord)},
		};
		

		//const response = await fetch('https://'+this.api_server_address+'/api/v1/projects', requestOptions)
		const response = await fetch('api/v1/projects', requestOptions)
		.then(function (response) {
			if (!response.ok){
				return;
			}
			else
				return response.json();
		});
		if(response){
			this.projects = response.data;
			//window.localStorage.setItem("api-server-address",this.api_server_address);
		}

		const resp = await fetch('api/v1/statistics', requestOptions)
		.then(function (resp) {
			if (!resp.ok){
				return;
			}
			else
				return resp.json();
		});
		if(resp){
			var jobs_stats = resp.data.jobs;
			for (let i = 0; i < jobs_stats.length; i++) {
				if(jobs_stats[i].status=="COMPLETED"){
					this.number_jobs_completed = jobs_stats[i].count;
				}
				else if(jobs_stats[i].status=="RUNNING"){
					this.number_jobs_running = jobs_stats[i].count;
				}
				else if(jobs_stats[i].status=="ERROR"){
					this.number_jobs_error = jobs_stats[i].count;
				}
			}
			this.number_transcoded_videos = resp.data.transcoded_files;
		}

		const response1 = await fetch('api/v1/projects/*/jobs', requestOptions)
		.then(function (response1) {
			if (!response1.ok){
				return null;
			}
			else
				return response1.json();
		});
		if(response1){
			this.jobs = response1.data;
			this.filtered_jobs = this.jobs;
		}

	},

	methods: {
		fetch_projects: async function () {
			requestOptions = {
                method: "GET",
                headers: { "Content-Type": "application/json",},// "Authorization": "Basic " + btoa(userName + ":" + passWord)},
            };
			const response = await fetch('api/v1/projects', requestOptions)
			.then(function (response) {
				if (!response.ok){
					return;
				}
				else
					return response.json();
			});
			if(response){
				this.projects = response.data;
				//window.localStorage.setItem("api-server-address",this.api_server_address);
			}

		},

		switch_state: async function(project){	
			var state;
			if(project.state=='active')
				state='inactive';
			else
				state='active';
			requestOptions = {
                method: "PUT",
                headers: { "Content-Type": "application/json", },//"Authorization": "Basic " + btoa(userName + ":" + passWord)},
				body: JSON.stringify({
                    "state": state,
                }),
            };
			const response = await fetch('api/v1/projects/'+project.id, requestOptions)
			.then(function (response) {
				if (!response.ok)
					alert('State Switch Failed!');
				else
					return response.json();
			});

			this.fetch_projects();

		},

		filter: function(){
			this.filtered_jobs = [];
			if(this.jobs_filter_status[0]){
				var temp = this.jobs.filter(job => job.status == "COMPLETED");
				for (let i = 0; i < temp.length; i++) {
					this.filtered_jobs.push(temp[i]);
				} 
			}
			if(this.jobs_filter_status[1]){
				var temp = this.jobs.filter(job => job.status === "RUNNING");
				for (let i = 0; i < temp.length; i++) {
					this.filtered_jobs.push(temp[i]);
				} 
			}
			if(this.jobs_filter_status[2]){
				var temp = this.jobs.filter(job => job.status === "ERROR");
				for (let i = 0; i < temp.length; i++) {
					this.filtered_jobs.push(temp[i]);
				} 
			}
		},

		create_project: async function(){
			var ffmpeg_command = ' ';

			for(let i = 0; i < this.number_of_streams; i++){
				ffmpeg_command = ffmpeg_command + ' -map v:0 -s:'+i+' '+ this.selected_video_resolution[i]+ ' -b:v:'+i+' '+ this.selected_video_bitrate[i]+'M -maxrate '+ this.selected_video_bitrate_maximum[i]+'M -minrate '+ this.selected_video_bitrate_minimum[i]+'M -bufsize '+ this.selected_buffer_size[i] +'M';
			}

			ffmpeg_command = ffmpeg_command + ' -map a:0?';
			if(this.protocol == 'hls'){
				for(let i = 1; i < this.number_of_streams; i++){
					ffmpeg_command = ffmpeg_command + ' -map a:0?';
				}
			}
			ffmpeg_command = ffmpeg_command + ' -c:a aac -b:a 128k -ac 1 -ar 44100 -keyint_min ' + this.gop_size +' -g ' + this.gop_size+ ' -c:v ' + this.codec + ' -f '+ this.protocol;
			
			if(this.protocol == 'hls')
				ffmpeg_command = ffmpeg_command + ' -hls_time ' + this.seg_dur+ ' -hls_playlist_type vod -hls_segment_filename stream_%v_%03d.ts -master_pl_name master.m3u8 ';
			else
				ffmpeg_command = ffmpeg_command + ' -seg_duration ' + this.seg_dur+ ' -use_template 1 -use_timeline 1';

			/*var ffmpeg_stream_map = 'v:0,a:0';
			for(let i = 1; i < this.number_of_streams; i++){
				ffmpeg_stream_map = ffmpeg_stream_map + ' v:'+i+',a:'+i;
			}*/
			requestOptions = {
                method: "POST",
                headers: { "Content-Type": "application/json",},// "Authorization": "Basic " + btoa(userName + ":" + passWord)},
				body: JSON.stringify({
					"TC_PROJECT_NAME": this.new_project_name,
					"TC_SRC_BUCKET": this.new_src_bucket,
					"TC_DST_BUCKET": this.new_dst_bucket,
					"TC_FFMPEG_CONFIG":ffmpeg_command,
					//"TC_FFMPEG_STREAM_MAP":ffmpeg_stream_map,
                }),
            };
			var that = this;
			const response = await fetch('api/v1/projects', requestOptions)
			.then(function (response) {
				if (!response.ok)
					alert('Project Creation Failed!');
				else{
					alert('Project Created!');
					that.clear_form();
					return response.json();
				}
			});
			this.fetch_projects();
		},
		clear_form : function(){
			this.new_project_name ='';
			this.new_src_bucket = '';
			this.new_dst_bucket = '';
			this.advanced = false;
			this.number_of_streams = 3;
			this.selected_video_resolution = ['1920x1080', '1280x720', '640x360', '640x360', '640x360', '640x360', '640x360', '640x360', '640x360', '640x360'];
            this.selected_video_bitrate = [5, 3, 1, 1, 1, 1, 1, 1, 1, 1];
            this.selected_video_bitrate_minimum = [5, 3, 1, 1, 1, 1, 1, 1, 1, 1];
            this.selected_video_bitrate_maximum = [5, 3, 1, 1, 1, 1, 1, 1, 1, 1];
            this.selected_buffer_size = [10, 3, 1, 1, 1, 1, 1, 1, 1, 1];
		},
		show_options : function(){
			this.advanced = !this.advanced;
		},
		logout : async function(){
			var that = this;
			requestOptions = {
                method: "GET",
                headers: { "Content-Type": "application/json"},
            };
			var status_code;
			const response = await fetch('/api/v1/logout', requestOptions)
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
			if(status_code != 400)
				window.location.replace("login.html");
		},
	},

	computed: {
        /*isDisabled: function () {
			if (/^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/.test(this.api_server_address)) {  
				return (false)  
			}  
			else
			  return true;
            
        },*/

		isDisabled2: function () {
			return this.new_project_name.length > 0 && this.new_src_bucket.length > 0 && this.new_dst_bucket.length > 0 && this.new_src_bucket != this.new_dst_bucket;
        },
		
	}
}

const app = Vue.createApp(project).mount('#api-server')


const navbar = {
	data() {
		return {
			//api_server_address: '',	
			//api_server_address: '129.159.119.35',
			
			password: '',
			new_password: '',
			new_password2: '',
			msg: '',
			
			email: '',
			is_admin: false,
			pending_requests: 0,
			users: '',
			filtered_users: '',

			all_users_filter_status : [true, true, true],
		}
	},
	async created(){
		await this.get_identity();
		if(this.is_admin)
			this.get_requests("pending");
	},
	async mounted(){
		
	},
	methods: {
		logout : async function(){
			var that = this;
			requestOptions = {
                method: "GET",
                headers: { "Content-Type": "application/json"},
            };
			var status_code;
			const response = await fetch('/api/v1/logout', requestOptions)
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
				window.location.replace("login.html");
			}
		},
		change_password: async function(){
			var that = this;
			requestOptions = {
                method: "PUT",
                headers: { "Content-Type": "application/json"},
				body: JSON.stringify({
					"password": this.password,
					"new_password": this.new_password,
                }),
            };
			var status_code;
			const response = await fetch('/api/v1/update_password', requestOptions)
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
				alert("Password Update Failed");
		},
		clear_form: function(){
			this.password = '';
			this.new_password = '';
			this.new_password2 = '';
		},
		get_requests: async function(status){
			var that = this;
			requestOptions = {
                method: "GET",
                headers: { "Content-Type": "application/json", },//"Authorization": "Basic " + btoa(userName + ":" + passWord)},
            };
			var status_code;
			const response = await fetch('/api/v1/users/'+status, requestOptions)
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
				this.users = response.data;
				this.filtered_users = this.users;
				if(status=='pending')
					this.pending_requests = this.users.length;
			}
		},
		change_user: async function(user, status, is_admin){
			var that = this;
			requestOptions = {
                method: "PUT",
                headers: { "Content-Type": "application/json",},//"Authorization": "Basic " + btoa(userName + ":" + passWord)},
				body: JSON.stringify({
					"email": user.email,
					"status": status,
					"is_admin": is_admin,
                }),
            };
			var status_code;
			const response = await fetch('/api/v1/update_user', requestOptions)
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
				user.status = status;
				user.is_admin = is_admin;
				this.pending_requests -= 1;
			}	
		},
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
				this.is_admin = response.data.is_admin;
				this.email = response.data.username;
			}
			else{
				window.location.replace("login.html");
			}
				
		},
		filter: function(){
			this.filtered_users = [];
			if(this.all_users_filter_status[0]){
				var temp = this.users.filter(user => user.status == "active");
				for (let i = 0; i < temp.length; i++) {
					this.filtered_users.push(temp[i]);
				} 
			}
			if(this.all_users_filter_status[1]){
				var temp = this.users.filter(user => user.status === "inactive");
				for (let i = 0; i < temp.length; i++) {
					this.filtered_users.push(temp[i]);
				} 
			}
			if(this.all_users_filter_status[2]){
				var temp = this.users.filter(user => user.status === "pending");
				for (let i = 0; i < temp.length; i++) {
					this.filtered_users.push(temp[i]);
				} 
			}
		},

	},
	computed: {
		isDisabled : function(){
			if(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,32}$/.test(this.password) && /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,32}$/.test(this.new_password) && this.new_password == this.new_password2)
				return false;
			return true;
			//return true;
		}
	}
}

const logoutapp = Vue.createApp(navbar).mount('#navbarNav')

