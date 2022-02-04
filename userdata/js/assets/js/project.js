var userName = "RestApiUser";
var passWord = "Tr@nsc0de!";

//var base_end_point = "https://objectstorage.us-ashburn-1.oraclecloud.com/p/qb8pLDV51o42MV9m2VNi2HxLQZQkbmoPHV0an1Hc_uGT4e-v8zeLj2kVeRlMW0A5/n/ocisateam/b/sourceBucket/o/"; Previously used to upload objects

var region_os_end_point = "https://objectstorage.us-ashburn-1.oraclecloud.com";

const video_player = {
	data() {
		return {
			project_name: '',
			src_bucket: '',
			dst_bucket: '',
			advanced: false,
			number_of_streams: 0,
			selected_video_resolution: ['1920x1080', '1280x720', '640x360', '640x360', '640x360', '640x360', '640x360', '640x360', '640x360', '640x360'],
            selected_video_bitrate : [5, 3, 1, 1, 1, 1, 1, 1, 1, 1],
            selected_video_bitrate_minimum : [5, 3, 1, 1, 1, 1, 1, 1, 1, 1],
            selected_video_bitrate_maximum : [5, 3, 1, 1, 1, 1, 1, 1, 1, 1],
            selected_buffer_size : [10, 3, 1, 1, 1, 1, 1, 1, 1, 1],

			file: '',
			access_uri: '',
			show: false,
			status: '',
			failed: false,
			num_of_parts: 0,
			completed_parts: 0,
			in_progress: false,
			vis_fail: false,
			vis_success: false,

			playlist: '',
			thumbnails: '',
			source: '',
			poster: '',
			width: 1500,
			height: 1200,
			project_end_point: '',
			//api_server_address: '',
			project_id: '',
			project_details: '',
			project_configuration: '',
			jobs: '',
			filtered_jobs: '',
			videos: '',
			jobs_filter_status: [true,true,true],
			
			base_end_point: "https://objectstorage.us-ashburn-1.oraclecloud.com/p/whADXRSimat_aU48js9EzvabSBvNLDU6yQDAxGx9z0er2uVyLKtVHVN6CYV25hkJ/n/ocisateam/b/output_images/o/",
			hls : '',
		}
	},
	async mounted() {
		//this.api_server_address = window.localStorage.getItem("api-server-address");
		var prmstr = window.location.search.substr(1);
		if(prmstr != null && prmstr != "")
			this.project_id = prmstr.split("=")[1]; 
		else
			return;
		
		var requestOptions = {
			method: "GET",
			headers: { "Content-Type": "application/json",} //"Authorization": "Basic " + btoa(userName + ":" + passWord)},
		};
		const response1 = await fetch('api/v1/projects/'+this.project_id, requestOptions)
		.then(function (response1) {
			if (!response1.ok){
				//alert('Unable to Load!');
				return null;
			}
			else
				return response1.json();
		});
		if(response1){
			this.project_details = response1.data;
			region_os_end_point = this.project_details.input_bucket_PAR.split("/p")[0];
			this.base_end_point = this.project_details.output_bucket_PAR;
		}
		
		const response = await fetch('api/v1/projects/'+this.project_id+'/objects', requestOptions)
			.then(function (response) {
				if (!response.ok){
					//alert('Unable to Fetch Playlist!');
					return null;
				}
				else
					return response.json();
		});
		if(response){
			this.videos = response.data;
		}

		if(this.videos.length > 0){
			var x = 70;
			this.width = Math.ceil(document.documentElement.clientWidth / 100) * x;
			//this.height = Math.ceil(document.documentElement.clientHeight/100)*y;
			const element = this.$refs.vp;
			element.scrollIntoView();
			this.source = this.base_end_point + this.videos[0].object;
			if (Hls.isSupported()) {
				this.hls = new Hls();
				this.hls.loadSource(this.source);
				this.hls.attachMedia(element);
				this.hls.on(Hls.Events.MANIFEST_PARSED, function () {
					this.$refs.vp.play();
				});
			}
		}


		/*response = await fetch(this.base_end_point)
			.then(function (response) {
				if (!response.ok)
					alert('Unable to Load!');
				else
					return response.json();
			});
		this.thumbnails = response.objects.filter(x => x['name'].substring(0, 11) === 'thumbnails/');
		this.poster = this.base_end_point + this.thumbnails[0].name;

		this.playlist = response.objects.filter(x => x['name'].substring(x['name'].length - 11) === 'master.m3u8');
		this.source = this.base_end_point + this.playlist[0].name;*/
		

		const response2 = await fetch('api/v1/projects/'+this.project_id+'/configuration', requestOptions)
		.then(function (response2) {
			if (!response2.ok){
				//alert('Unable to Load!');
				return null;
			}
			else
				return response2.json();
		});
		if(response2){
			this.project_configuration = response2.data;
		}

		const response3 = await fetch('api/v1/projects/'+this.project_id+'/jobs', requestOptions)
			.then(function (response3) {
				if (!response3.ok){
					//alert('Unable to Fetch Jobs!');
					return null;
				}
				else
					return response3.json();
			});
			if(response3){
				this.jobs = response3.data;
				this.filtered_jobs = this.jobs;
			}
	},
	methods: {
		play_video: function (video) {
			element = this.$refs.vp;
			element.scrollIntoView();
			/*this.source = this.base_end_point + video;
			this.hls.loadSource(this.source);
			this.hls.attachMedia(element);
			this.hls.on(Hls.Events.MANIFEST_PARSED, function () {
				element.play();
			});*/
			this.source = this.base_end_point + video.object;
			this.hls.loadSource(this.source);
			this.hls.attachMedia(element);
			this.hls.on(Hls.Events.MANIFEST_PARSED, function () {
				element.play();
			});

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
		onFileChange: function (e) {
			var files = e.target.files || e.dataTransfer.files;
			if (!files.length)
				return;
			this.file = files[0];
			this.show = true;
		},
		upload_file: async function () {
			var that = this;
			var end_point = this.project_details.input_bucket_PAR + this.file.name;
			var chunk_size = 64000000;
			//var chunk_size = 1500000;
			this.num_of_parts = Math.ceil(this.file.size / chunk_size);

			this.in_progress = true;

			if (this.num_of_parts < 2) {
				this.upload_single_part(end_point);
			}
			else {
				const requestOptions = {
					method: "PUT",
					headers: { "opc-multipart": true },
				};

				const response = await fetch(end_point, requestOptions)
				.then(function(response){
					if(!response.ok)
						throw Error(response.statusText);
					else
						return response.json();
					}).catch(function(error){
						that.failed = true;
					});

				if (this.failed != true) {
					this.access_uri = response.accessUri;
					code = await this.upload_multi_part(chunk_size);
					end_point = region_os_end_point + this.access_uri;
					if (this.failed == true) {
						const requestOptions = {
							method: "DELETE",
						};
						fetch(end_point, requestOptions);
					}
					else {
						const requestOptions = {
							method: "POST",
						};
						fetch(end_point, requestOptions);
					}

				}
				this.in_progress = false;
				if (this.failed) {
					this.vis_fail = true;
					setTimeout(() => this.vis_fail = false, 5000);
				}
				else {
					this.file = '';
					this.show = false;
					this.vis_success = true;
					const input = this.$refs.fileupload;
        			input.type = 'text';
        			input.type = 'file';
					setTimeout(() => this.vis_success = false, 5000);
				}
			}
			this.failed = false;
			this.num_of_parts = 0;
			this.completed_parts = 0;
		},
		upload_single_part: function (end_point) {
			var that = this;
			const requestOptions = {
				method: "PUT",
				headers: { "Content-Type": this.file.type },
				body: this.file,
			};
			fetch(end_point, requestOptions).then(function (response) {
				if (response.status != 200) {
					that.failed = true;
					that.in_progress = false;
					that.vis_fail = true;
					setTimeout(() => that.vis_fail = false, 5000);
				}
				else {
					that.completed_parts += 1;
					that.in_progress = false;
					that.file = '';
					
					const input = that.$refs.fileupload;
        			input.type = 'text';
        			input.type = 'file';
					that.show = false;
					that.vis_success = true;
					setTimeout(() => that.vis_success = false, 5000);
				}
			});
		},
		upload_single_in_multi_part: async function (file_part, end_point, num_of_retries) {
			var that = this;
			const requestOptions = {
				method: "PUT",
				body: file_part,
			};
			function onError(){
				num_of_retries -= 1;
				if(num_of_retries == 0){
					that.failed = true;
					return;
				}
				return setTimeout(function(){that.upload_single_in_multi_part(file_part, end_point, num_of_retries); }, 3000);
				
			}
			await fetch(end_point, requestOptions)
			.then(function(response){
				if(!response.ok)
					throw Error(response.statusText);
				else
					that.completed_parts += 1;
			}).catch(onError);
		},
		upload_multi_part: async function (chunk_size) {
			var start = 0;
			var end = chunk_size;
			this.in_progress = true;
			let promises = [];

			for (let i = 1; i < this.num_of_parts + 1; i++) {
				var file_part = this.file.slice(start, end);
				var end_point = region_os_end_point + this.access_uri + i;
				promises.push(this.upload_single_in_multi_part(file_part, end_point, 3));
				start += chunk_size;
				end += chunk_size;

			}
			const res = await Promise.all(promises);
			
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

			requestOptions = {
				method: "GET",
				headers: { "Content-Type": "application/json",},// "Authorization": "Basic " + btoa(userName + ":" + passWord)},
			};
			const response1 = await fetch('api/v1/projects/'+this.project_id, requestOptions)
			.then(function (response1) {
				if (!response1.ok){
					alert('Unable to Load!');
					return null;
				}
				else
					return response1.json();
			});
			if(response1){
				this.project_details = response1.data;
			}

		},
		update_configuration: async function(){
			var ffmpeg_command = ' ';
			for(let i = 0; i < this.number_of_streams; i++){
				ffmpeg_command = ffmpeg_command + ' -map v:0 -s:'+i+' '+ this.selected_video_resolution[i]+ ' -b:v:'+i+' '+ this.selected_video_bitrate[i]+'M -maxrate '+ this.selected_video_bitrate_maximum[i]+'M -minrate '+ this.selected_video_bitrate_minimum[i]+'M -bufsize '+ this.selected_buffer_size[i] +'M';
			}
			for(let i = 0; i < this.number_of_streams; i++){
				ffmpeg_command = ffmpeg_command + ' -map a:0'
			}
			ffmpeg_command = ffmpeg_command + ' -c:a aac -b:a 128k -ac 1 -ar 44100 -g 48 -sc_threshold 0 -c:v libx264 -f hls -hls_time 5 -hls_playlist_type vod -hls_segment_filename stream_%v_%03d.ts -master_pl_name master.m3u8 ';
			var ffmpeg_stream_map = 'v:0,a:0';
			for(let i = 1; i < this.number_of_streams; i++){
				ffmpeg_stream_map = ffmpeg_stream_map + ' v:'+i+',a:'+i;
			}
			
			requestOptions = {
                method: "PUT",
                headers: { "Content-Type": "application/json", },//"Authorization": "Basic " + btoa(userName + ":" + passWord)},
				body: JSON.stringify({
					"TC_PROJECT_NAME": this.project_name,
					"TC_SRC_BUCKET": this.src_bucket,
					"TC_DST_BUCKET": this.dst_bucket,
					"TC_FFMPEG_CONFIG":ffmpeg_command,
					//"TC_FFMPEG_STREAM_MAP": ffmpeg_stream_map,
                }),
            };
			const response = await fetch('api/v1/projects/'+this.project_details.id+'/configuration', requestOptions)
			.then(function (response) {
				if (!response.ok){
					alert('Configuration Update Failed!');
					return null;
				}
				else{
					alert('Configuration updated successfully!');
					return response.json();
				}
			});

			requestOptions = {
				method: "GET",
				headers: { "Content-Type": "application/json",},// "Authorization": "Basic " + btoa(userName + ":" + passWord)},
			};

			const response2 = await fetch('api/v1/projects/'+this.project_id+'/configuration', requestOptions)
			.then(function (response2) {
				if (!response2.ok){
					alert('Unable to Load!');
					return null;
				}
				else
					return response2.json();
			});
			if(response2){
				this.project_configuration = response2.data;
			}
		},
		load_form: async function(){
			this.project_name = this.project_configuration.TC_PROJECT_NAME;
			this.src_bucket = this.project_configuration.TC_SRC_BUCKET;
			this.dst_bucket = this.project_configuration.TC_DST_BUCKET;
			this.number_of_streams =  (this.project_configuration.TC_FFMPEG_CONFIG.match(/-map/g) || []).length/2;
			
			var config_split= this.project_configuration.TC_FFMPEG_CONFIG.trim().replaceAll('M', '').split(" ");

			//console.log("%o", config_split);
			for(let i = 0; i < this.number_of_streams; i++){
				this.selected_video_resolution[i] = config_split[3+(12*i)];
				this.selected_video_bitrate[i]  = config_split[5+(12*i)];
				this.selected_video_bitrate_minimum[i] = config_split[9+(12*i)];
				this.selected_video_bitrate_maximum[i] = config_split[7+(12*i)];
				this.selected_buffer_size[i] = config_split[11+(12*i)];
			}
		},
		show_options : function(){
			this.advanced = !this.advanced;
		},
	},

	computed: {
		isDisabled2: function () {
			return (this.src_bucket.length == 0 && this.dst_bucket.length == 0) || (this.src_bucket.length == this.dst_bucket.length);
        },
	}
}

const player = Vue.createApp(video_player).mount('#video_player')



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

