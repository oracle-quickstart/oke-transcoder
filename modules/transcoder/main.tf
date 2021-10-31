# OCI CLI Installation

data "template_file" "install_oci_cli" {
  template = file("${path.module}/../../userdata/scripts/cli_config.sh")
}

resource null_resource "install_oci_cli" {
  depends_on = [var.transcoder_depends_on]

  connection {
    host        = var.instance_ip
    private_key = var.ssh_private_key
    timeout     = "200s"
    type        = "ssh"
    user        = "opc"
  }

  provisioner "file" {
    content     = data.template_file.install_oci_cli.rendered
    destination = "~/cli_config.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x $HOME/cli_config.sh",
      "bash $HOME/cli_config.sh",
      "rm -f $HOME/cli_config.sh",
      "rm -f $HOME/install.sh"
    ]
  }
}

# Create transcode DB and grant tc user full access to it

data "template_file" "create_db" {
  template = file("${path.module}/../../userdata/scripts/create_db.sh")
  vars = {
    db_ip = var.db_ip
    db_name = var.db_name
    admin_db_user = var.admin_db_user
    admin_db_password = var.db_password
    db_user = var.db_user
    db_password = var.db_password
  }
}

resource "null_resource" "create_db" {
  depends_on = [var.transcoder_depends_on]
  connection {
    host        = var.instance_ip
    private_key = var.ssh_private_key
    timeout     = "40m"
    type        = "ssh"
    user        = "opc"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p $HOME/transcoder/build"
    ]
  }

  provisioner "file" {
    content     = data.template_file.create_db.rendered
    destination = "~/transcoder/build/create_db.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "cd $HOME/transcoder/build",
      "chmod +x create_db.sh",
      "./create_db.sh",
      "rm -f create_db.sh"
    ]
  }
}

# Kubectl

data "template_file" "install_kubectl" {
  template = file("${path.module}/../../userdata/scripts/install_kubectl.sh")
   vars = {
    cpu_arch = var.cpu_arch
  }
}

resource "null_resource" "install_kubectl" {
  depends_on = [null_resource.install_oci_cli]

  connection {
    host        = var.instance_ip
    private_key = var.ssh_private_key
    timeout     = "40m"
    type        = "ssh"
    user        = "opc"
  }

  provisioner "file" {
    content     = data.template_file.install_kubectl.rendered
    destination = "~/install_kubectl.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x $HOME/install_kubectl.sh",
      "bash $HOME/install_kubectl.sh",
      "rm -f $HOME/install_kubectl.sh"
    ]
  }
}

# Kubeconfig

data "template_file" "generate_kubeconfig" {
  template = file("${path.module}/../../userdata/scripts/generate_kubeconfig.sh")

  vars = {
    cluster-id = var.cluster_id
    region     = var.region
  }
}

resource "null_resource" "generate_kubeconfig" {
  depends_on = [null_resource.install_oci_cli]

  connection {
    host        = var.instance_ip
    private_key = var.ssh_private_key
    timeout     = "40m"
    type        = "ssh"
    user        = "opc"
  }

  provisioner "file" {
    content     = data.template_file.generate_kubeconfig.rendered
    destination = "~/generate_kubeconfig.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x $HOME/generate_kubeconfig.sh",
      "$HOME/generate_kubeconfig.sh",
      "rm -f $HOME/generate_kubeconfig.sh"
    ]
  }
}

# Checking node lifecycle state

data "template_file" "check_node_lifecycle" {
  template = file("${path.module}/../../userdata/scripts/is_worker_active.sh")

  vars = {
    nodepool-id = var.nodepool_id
  }
}

resource "null_resource" "node_lifecycle" {
  depends_on = [null_resource.install_oci_cli]

  connection {
    host        = var.instance_ip
    private_key = var.ssh_private_key
    timeout     = "40m"
    type        = "ssh"
    user        = "opc"
  }

  provisioner "file" {
    content     = data.template_file.check_node_lifecycle.rendered
    destination = "~/is_worker_active.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x $HOME/is_worker_active.sh",
      "$HOME/is_worker_active.sh",
      "rm -f $HOME/is_worker_active.sh"
    ]
  }
}


# Install docker
data "template_file" "install_docker" {
  template = file("${path.module}/../../userdata/scripts/install_docker.sh")
  vars = {
    user = "opc" 
  }
}
resource "null_resource" "install_docker" {
  depends_on = [null_resource.install_oci_cli]
  
  connection {
    host        = var.instance_ip
    private_key = var.ssh_private_key
    timeout     = "40m"
    type        = "ssh"
    user        = "opc"
  }

  provisioner "file" {
    content     = data.template_file.install_docker.rendered
    destination = "~/install_docker.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x $HOME/install_docker.sh",
      "$HOME/install_docker.sh",
      "rm -f $HOME/install_docker.sh"
    ]
  }
}

# Build scheduler docker image
data "template_file" "scheduler_dockerfile" {
  template = file("${path.module}/../../userdata/scheduler/Dockerfile")
}
data "template_file" "consumer" {
  template = file("${path.module}/../../userdata/scheduler/consumer.py")
}
data "template_file" "new_job" {
  template = file("${path.module}/../../userdata/scheduler/new_job.py")
  vars = {
    db_host = var.db_ip
    db_name = var.db_name
    db_user = var.db_user
    db_password = var.db_password
  }
}

resource "null_resource" "build_scheduler_docker_image" {
  depends_on = [null_resource.install_docker]

  connection {
    host        = var.instance_ip
    private_key = var.ssh_private_key
    timeout     = "40m"
    type        = "ssh"
    user        = "opc"
  }
  
  provisioner "remote-exec" {
    inline = [
      "mkdir -p $HOME/transcoder/scheduler"
        ]
  }

  provisioner "file" {
    content     = data.template_file.scheduler_dockerfile.rendered
    destination = "~/transcoder/scheduler/Dockerfile"
  }
  
  provisioner "file" {
    content     = data.template_file.consumer.rendered
    destination = "~/transcoder/scheduler/consumer.py"
  }

  provisioner "file" {
    content     = data.template_file.new_job.rendered
    destination = "~/transcoder/scheduler/new_job.py"
  }

  provisioner "remote-exec" {
    inline = [
      "cd $HOME/transcoder/scheduler",
      "docker build -t scheduler:${var.image_label} . --no-cache"
    ]
  }
}

# Build transcoder docker image
data "template_file" "transcoder_dockerfile" {
  template = file("${path.module}/../../userdata/transcoder/Dockerfile")
  vars = {
    cpu_arch = var.cpu_arch 
  }
}
data "template_file" "transcode" {
  template = file("${path.module}/../../userdata/transcoder/transcode.sh")
}

resource "null_resource" "build_transcoder_docker_image" {
  depends_on = [null_resource.install_docker]

  connection {
    host        = var.instance_ip
    private_key = var.ssh_private_key
    timeout     = "40m"
    type        = "ssh"
    user        = "opc"
  }
  
  provisioner "remote-exec" {
    inline = [
      "mkdir -p $HOME/transcoder/transcode"
        ]
  }


  provisioner "file" {
    content     = data.template_file.transcoder_dockerfile.rendered
    destination = "~/transcoder/transcode/Dockerfile"
  }
  
  provisioner "file" {
    content     = data.template_file.transcode.rendered
    destination = "~/transcoder/transcode/transcode.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "cd $HOME/transcoder/transcode",
      "docker build -t transcoder:${var.image_label} . --no-cache"
    ]
  }
}


# Build api-server docker image
data "template_file" "api_dockerfile" {
  template = file("${path.module}/../../userdata/api/Dockerfile")
}
data "template_file" "api_bootstrap" {
  template = file("${path.module}/../../userdata/api/bootstrap.sh")
}
data "template_file" "api_index" {
  template = file("${path.module}/../../userdata/api/index.py")
  vars = {
    namespace = var.namespace
    event_rule_id = var.event_rule_id
  }
}

resource "null_resource" "build_api_docker_image" {
  depends_on = [null_resource.install_docker]

  connection {
    host        = var.instance_ip
    private_key = var.ssh_private_key
    timeout     = "40m"
    type        = "ssh"
    user        = "opc"
  }
  
  provisioner "remote-exec" {
    inline = [
      "mkdir -p $HOME/transcoder/api"
        ]
  }


  provisioner "file" {
    content     = data.template_file.api_dockerfile.rendered
    destination = "~/transcoder/api/Dockerfile"
  }
  
  provisioner "file" {
    content     = data.template_file.api_bootstrap.rendered
    destination = "~/transcoder/api/bootstrap.sh"
  }

  provisioner "file" {
    content     = data.template_file.api_index.rendered
    destination = "~/transcoder/api/index.py"
  }

  provisioner "remote-exec" {
    inline = [
      "cd $HOME/transcoder/api",
      "openssl req -x509 -newkey rsa:4096 -nodes -out cert.pem -keyout key.pem -days 365 -subj ${var.ssl_cert_subject}",
      "docker build -t api-server:${var.image_label} . --no-cache"
    ]
  }
}

# Push sheduler and transcoder and api-server docker images to OCIR registry
data "template_file" "push_to_registry" {
  template = file("${path.module}/../../userdata/scripts/push_to_registry.sh")
  vars = {
    secret_id = var.secret_id,
    registry = var.registry
    repo_name = var.repo_name
    registry_user = var.registry_user
    tenancy_name = data.oci_identity_tenancy.my_tenancy.name
    region = var.region
    image_label = var.image_label
  }
}

resource "null_resource" "push_to_registry" {
  depends_on = [null_resource.install_docker, null_resource.build_scheduler_docker_image, null_resource.build_transcoder_docker_image, null_resource.build_api_docker_image]

  connection {
    host        = var.instance_ip
    private_key = var.ssh_private_key
    timeout     = "40m"
    type        = "ssh"
    user        = "opc"
  }

  provisioner "file" {
    content     = data.template_file.push_to_registry.rendered
    destination = "~/transcoder/build/push_to_registry.sh"
  }
  
  provisioner "remote-exec" {
    inline = [
      "cd $HOME/transcoder/build",
      "chmod +x push_to_registry.sh",
      "./push_to_registry.sh scheduler",
      "./push_to_registry.sh transcoder",
      "./push_to_registry.sh api-server"
    ]
  }
}

# Install cluster-autoscaler

data "template_file" "cluster_autoscaler_template" {
  template = file("${path.module}/../../userdata/templates/cluster-autoscaler.yaml.template")
  vars = {
    cluster_autoscaling = var.cluster_autoscaling
    oci_cluster_autoscaler_image = var.oci_cluster_autoscaler_image
    min_worker_nodes = var.min_worker_nodes
    max_worker_nodes = var.max_worker_nodes
    nodepool_id = var.nodepool_id
  }
}
  
resource "null_resource" "cluster_autoscaler" {
 depends_on = [ null_resource.node_lifecycle, null_resource.generate_kubeconfig, null_resource.install_kubectl ]

  connection {
    host        = var.instance_ip
    private_key = var.ssh_private_key
    timeout     = "40m"
    type        = "ssh"
    user        = "opc"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p $HOME/transcoder/build"
    ]
  }

  provisioner "file" {
    content     = data.template_file.cluster_autoscaler_template.rendered
    destination = "~/transcoder/build/cluster-autoscaler.yaml"
  } 

  provisioner "remote-exec" {
    inline = [
      "cd $HOME/transcoder/build",
      "kubectl apply -f cluster-autoscaler.yaml"
    ]
  }
}

# Deploy scheduler container on OKE

data "template_file" "deploy" {
  template = file("${path.module}/../../userdata/scripts/deploy.sh")
  vars = {
    secret_id = var.secret_id
    registry = var. registry
    repo_name = var.repo_name
    registry_user = var.registry_user
    tenancy_name = data.oci_objectstorage_namespace.lookup.namespace
    region = var.region
    image_label = var.image_label
    namespace = var.namespace
    db_ip = var.db_ip
    db_name = var.db_name
    db_user = var.db_user
    db_password = var.db_password
    project_name = var.project_name
    src_bucket = var.src_bucket
    dst_bucket = var.dst_bucket
  }
}

data "template_file" "configmap_template" {
  template = file("${path.module}/../../userdata/templates/configmap.yaml.template")
  vars = {
    project_name = var.project_name
    namespace = var.namespace
    registry = var.registry
    tenancy_name = data.oci_identity_tenancy.my_tenancy.name
    repo_name = var.repo_name
    image_label = var.image_label
    nodepool_label = var.nodepool_label
    os_namespace = data.oci_objectstorage_namespace.lookup.namespace
    src_bucket = var.src_bucket
    dts_bucket = var.dst_bucket
    stream_ocid = var.stream_ocid
    stream_endpoint = var.stream_endpoint
    ffmpeg_config = var.ffmpeg_config
    ffmpeg_stream_map = var.ffmpeg_stream_map
    hls_stream_url = var.hls_stream_url
    db_ip = var.db_ip
    db_name = var.db_name
    db_user = var.db_user
    cpu_request_per_job = var.cpu_request_per_job
  }
}

data "template_file" "db_secret_template" {
  template = file("${path.module}/../../userdata/templates/db-secret.yaml.template")
  vars = {
    db_password = base64encode(var.db_password)
  }
}

data "template_file" "scheduler_template" {
  template = file("${path.module}/../../userdata/templates/scheduler.yaml.template")
  vars = {
    namespace = var.namespace
    registry = var.registry
    tenancy_name = data.oci_objectstorage_namespace.lookup.namespace
    repo_name = var.repo_name
    image_name = "scheduler"
    image_label = var.image_label
    nodepool_label = var.nodepool_label
    project_name = var.project_name
  }
}

data "template_file" "api_server_template" {
  template = file("${path.module}/../../userdata/templates/api-server.yaml.template")
  vars = {
    namespace = var.namespace
    registry = var.registry
    tenancy_name = data.oci_objectstorage_namespace.lookup.namespace
    repo_name = var.repo_name
    image_name = "api-server"
    image_label = var.image_label
    nodepool_label = var.nodepool_label
    project_name = var.project_name
  }
}


resource "null_resource" "deploy_containers" {
 depends_on = [null_resource.push_to_registry, null_resource.create_db, null_resource.node_lifecycle, null_resource.generate_kubeconfig, null_resource.install_kubectl]

  connection {
    host        = var.instance_ip
    private_key = var.ssh_private_key
    timeout     = "40m"
    type        = "ssh"
    user        = "opc"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p $HOME/transcoder/build"
    ]
  }

  provisioner "file" {
    content     = data.template_file.configmap_template.rendered
    destination = "~/transcoder/build/configmap.yaml"
  }  

  provisioner "file" {
    content     = data.template_file.scheduler_template.rendered
    destination = "~/transcoder/build/scheduler.yaml"
  }  

  provisioner "file" {
    content     = data.template_file.api_server_template.rendered
    destination = "~/transcoder/build/api-server.yaml"
  } 

  provisioner "file" {
    content     = data.template_file.db_secret_template.rendered
    destination = "~/transcoder/build/db-secret.yaml"
  }  

  provisioner "file" {
    content     = data.template_file.deploy.rendered
    destination = "~/transcoder/build/deploy.sh"
  }


  provisioner "remote-exec" {
    inline = [
      "cd $HOME/transcoder/build",
      "chmod +x deploy.sh",
      "./deploy.sh"
    ]
  }
}
