resource "oci_events_rule" "new_file_uploaded" {
  #Required
  actions {
    actions {
      #Required
      action_type = "OSS"
      is_enabled  = true

      #Optional
      description = "description"
      stream_id   = var.stream_id
    }
  }
  compartment_id = var.compartment_ocid
  condition      = "{\"eventType\":[\"com.oraclecloud.objectstorage.createobject\"], \"data\":{\"additionalDetails\":{\"bucketName\":[\"${var.bucket_name}\"]}}}"
  display_name   = "new-file-uploaded"
  description = "This rule sends a message to the streaming queue when a new file is uploaded to object storage bucket"
  is_enabled     = true
}
