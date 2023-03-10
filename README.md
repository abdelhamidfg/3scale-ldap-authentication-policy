# 3scale LDAP Authentication Policy

This Policy allows APICast to determine if access to an API should be granted or denied  based on the provided credentials in the Authorization header,it extracts the user name and password from an HTTP Basic request and binds to LDAP using these credentials to check if the user name and password are valid.

 The configuration parameters :-
| Name  |  Type | Description  | Example |
|---|---|---|---|
|  ldap_host | string| Host on which the LDAP server is running | ldap.jumpcloud.com |
| ldap_port  | number| port where the LDAP server is listening  | 389  |
|  base_dn |  string| Base dn of the LDAP server | ou=Users,o=61ad22,dc=jumpcloud,dc=com  |
|  uid |  string| Attribute to be used to search the user | uid  |
|  error_message |  access is not allowed | Error message to show to user when traffic is blocked | 


## Policy Installation on OpenShift

The policy uses lua-resty-ldap dependency for connecting with an LDAP server which must be added on apicast base image.
# 1. Build Custom APIcast image
1. create openshift project.
   ```shell
   oc new-project <<apicast-ldap>>
   ```
2. create image stream.

   ```shell
   apiVersion: image.openshift.io/v1
   kind: ImageStream
   metadata:
    name: apicast-ldap
   ```
3. create openshift build.
   The build uses docker stratgy from the git repo , the docker uses apicast-gateway-rhel8:3scale2.13 as a base image,if you are using a diffeent version from 3scale the docker file needs to be updated to your version of 3scale.
```shell
 apiVersion: build.openshift.io/v1
 kind: BuildConfig 
 metadata:
  name: apicast-ldap
 spec:
  output:
    to:
      kind: ImageStreamTag
      name: 'apicast-ldap:latest'
  strategy:
     type: Docker
     dockerStrategy:
      dockerfilePath: Dockerfile
  source:
      type: Git
      git:
       uri: 'https://github.com/abdelhamidfg/ldap-authentication-policy'
 ```
4. start openshift build.
```shell
oc -n <<apicast-ldap>> start-build apicast-ldap --wait --follow
```

# 2. Deploy a self-managed  APIcast gateway 
1. Install the APIcast operator as described in the [documentation](https://github.com/3scale/apicast-operator/blob/master/doc/quickstart-guide.md#Install-the-APIcast-operator)
2. Create a kubernetes secret that contains a 3scale Porta admin portal endpoint information
```shell
oc create secret generic 3scaleportal --from-literal=AdminPortalURL=https://access-token@account-admin.3scale.net
```
3. create a secret contains the policy files (the files are existed in the repo folder /policies/ldap_authn/1.0.0)
```shell
oc create secret generic ldap-authn-policy   --from-file=ldap_authn.lua   --from-file=init.lua   --from-file=apicast-policy.json --from-file=ldap.lua --from-file=asn1.lua
```
4.Create APIcast custom resource instance
The image attrbuite should refered to the custom image build in step 1
```shell
apiVersion: apps.3scale.net/v1alpha1
kind: APIcast
metadata:
  name: apicast-ldap
spec: 
  adminPortalCredentialsRef:
    name: 3scaleportal
  replicas: 1  
  image: 'image-registry.openshift-image-registry.svc:5000/apicast-ldap-custom/apicast-ldap'
  customPolicies:
    - name: ldap_authn
      secretRef:
        name: ldap-authn-policy
      version: 1.0.0
```
5. Create 3scale CustomPolicyDefinition Custom Resource 
 in order to view the policy configuration in the API Manager policy editor UI , the custom policy should be registered using customPolicyDefinition custom resource

 ```shell
apiVersion: capabilities.3scale.net/v1beta1
kind: CustomPolicyDefinition
metadata:
  name: custompolicydefinition-ldap-authn
spec:
  name: "ldap_authn"
  version: "1.0.0"
  schema:
    name: "ldap_authn"
    version: "1.0.0"
    summary: "The policy checks for valid credentials in the Authorization header , extracts the user name and password from an HTTP Basic request and binds to LDAP using these credentials to check if the user name and password are valid"
    $schema: "http://json-schema.org/draft-07/schema#"
    configuration:
      type: "object"
      properties:
        ldap_host:
            description: "host of ldap server"
            type: "string"
        ldap_port:
            description: "port of ldap server"
            type: "number"
        base_dn:
            description: "Base dn of the LDAP server"
            type: "string"
        uid:
            description: "Attribute to be used to search the user"
            type: "string"
        error_message	:
            description: "Error message to show to user when traffic is blocked	"
            type: "string"
      providerAccountRef:
       name: threescale-provider-account
 ```
For more informatino about this step ,check the [documentation](https://github.com/3scale/3scale-operator/blob/master/doc/custompolicydefinition-reference.md#custompolicydefinitionschemaspec)
# 1. Testing the policy
1. Create an API Product and add the policy to the policy chain after the API Cast policy
2. provides configuration parameters  

```shell       
{
      "name": "ldap_authn",
      "version": "1.0.0",
      "configuration": {
        "ldap_host" : "ldap.jumpcloud.com",
        "ldap_port":389,
        "base_dn":"ou=Users,o=23221k2,dc=jumpcloud,dc=com",
        "uid": "uid"
    },
      "enabled": true
    }
```
3.Test the service 
```shell
  curl  <<url of the api product>> -u "username:password"
```
   
