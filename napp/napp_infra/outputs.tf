/**
 * Output details of findr eks module
*/
output "napp_eks_details" {

  /**
   * Description of output
   */
  description = "Cluster details"

  /**
   * Value from napp eks module
   */
  value = module.napp[*]

}


/**
 * Output details of napp-s3 module
*/ 
output "napp_s3_details" {

  /**
   * Description of output
   */
  description = "s3 bucket details"

  /**
   * Value from napp s3 module
   */
  value = module.napp-s3[*]

  sensitive = true

}
