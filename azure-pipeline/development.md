# Azure Pipeline task: NGINX for Azure Configuration Push (Development Guide)


For the developing and publishing of the pipeline task, there are two ways to build and update the Azure DevOps pipeline tasks onto the market place if there are any new fixes or patches. 

## Plan A. Manual Update

### Step 1. Get vss-extension.json ready for packaging

vss-extension.json defines all information about your extension that will be displayed in the marketplace. 

Please not that the name and id of this file is not finalized.

```json

// vss-extension.json

{
    "manifestVersion": 1,
    "id": "zao-nginx-config-push",
    "name": "zao-nginx-config-push",
    "version": "0.2.6",                                                    
    "publisher": "zaotest",
    "targets": [
        {
            "id": "Microsoft.VisualStudio.Services"
        }
    ],    
    "description": "Zao's tool for uploading nginx config",
    "categories": [
        "Azure Pipelines"
    ],
    "icons": {
        "default": "images/extension-icon.png"        
    },
    "files": [
        {
            "path": "src"
        }
    ],
    "contributions": [
        {
            "id": "custom-build-release-task",
            "type": "ms.vss-distributed-task.task",
            "targets": [
                "ms.vss-distributed-task.tasks"
            ],
            "properties": {
                "name": "src"
            }
        }
    ],
    "galleryFlags": [
        "Public"
    ],
    "public": false,
    "tags":[
        "Build task",
        "Deploy task"
    ]
}

```


If this is the first time you are publishing the extension onto the marketplace, make sure the following keys have corresponded and correct value: id, name, publisher, description, icons. Otherwise, if this is just a normal update, all you need to do is just to make sure that the version number is updated to a greater one.

For more details about vss-extension.json, please refer to ([Extension Manifest Reference - Azure DevOps | Microsoft Docs](https://docs.microsoft.com/en-us/azure/devops/extend/develop/manifest?view=azure-devops))

### Step 2. Package the extension

The whole project can be easily packaged by running the following single command:

```
tfx extension create --manifest-globs vss-extension.json
```

Now we will have a .vsix file generated automatically and ready for uploading to the marketplace portal.

If this is the first time you are using this command, you may need to install tfx-cli by:

```
npm install -g tfx-cli
```

### Step 3. Upload the .vsix file onto the marketplace

Sign in the Visual Studio Marketplace Publishing Portal. A normal update will be as easy as clicking the Update button of your extension and drag your .visx generated just now into it. 

![Image](images/readme-marketplace.png)


There will be a verification process running as soon as you uploaded the .visx file. Once the verification is completed, the Marketplace Publishing Portal will automatically update your extension to the newest version.

However, if this is the first time you are publishing the pipeline extension, please refer to Step 5: Publish your extension [Add a build or release task in an extension - Azure DevOps | Microsoft Docs](https://docs.microsoft.com/en-us/azure/devops/extend/develop/add-build-task?view=azure-devops#create-your-publisher) to learn about how to create a new publisher account.


## Plan B. Pipelined Update

You can also set up an Azure pipeline to automate the updating and releasing process with the following template:

```yaml
# build.yml
# This is an example pipeline if we need a pipeline to update the task onto the market place
# If we use manual update, this will not be needed.

trigger: 
- main

pool:
  vmImage: "ubuntu-latest"

variables:
  PublisherID: 
  ExtensionID: 
  ExtensionName: 
  ExtensionVersion: 
  ArtifactStagingDirectory: './artifact'
  ArtifactName: 'extension_artifact'



stages:
  - stage: Package_extension_and_publish_build_artifacts
    jobs:
      - job:
        steps:
          - task: TfxInstaller@3
            inputs:
              version: "v0.7.x"
          - task: Npm@1
            inputs:
              command: 'install'
              workingDir: './src' # Update to the name of the directory of your task
          - task: Bash@3
            displayName: Compile Javascript
            inputs:
              targetType: "inline"
              script: |
                cd src # Update to the name of the directory of your task
                tsc
          - task: QueryAzureDevOpsExtensionVersion@3
            inputs:
              connectTo: 'VsTeam'
              connectedServiceName: 'release-test-connection' # Change to whatever you named the service connection
              publisherId: '$(PublisherID)'
              extensionId: '$(ExtensionID)'
              versionAction: 'Patch'
              outputVariable: 'Task.Extension.Version'
          - task: PackageAzureDevOpsExtension@3
            inputs:
              rootFolder: '$(System.DefaultWorkingDirectory)'
              publisherId: '$(PublisherID)'
              extensionId: '$(ExtensionID)'
              extensionName: '$(ExtensionName)'
              extensionVersion: '$(ExtensionVersion)'
              updateTasksVersion: true
              updateTasksVersionType: 'patch'
              extensionVisibility: 'private' # Change to public if you're publishing to the marketplace
              extensionPricing: 'free'
          - task: CopyFiles@2
            displayName: "Copy Files to: $(ArtifactStagingDirectory)"
            inputs:
              Contents: "**/*.vsix"
              TargetFolder: "$(ArtifactStagingDirectory)"
          - task: PublishBuildArtifacts@1
            inputs:
              PathtoPublish: '$(ArtifactStagingDirectory)'
              ArtifactName: '$(ArtifactName)'
              publishLocation: 'Container'
  - stage: Download_build_artifacts_and_publish_the_extension
    jobs:
      - job:
        steps:
          - task: TfxInstaller@3
            inputs:
              version: "v0.7.x"
          - task: DownloadBuildArtifacts@0
            inputs:
              buildType: "current"
              downloadType: "single"
              artifactName: "$(ArtifactName)"
              downloadPath: "$(System.DefaultWorkingDirectory)"
          - task: PublishAzureDevOpsExtension@3
            inputs:
              connectTo: 'VsTeam'
              connectedServiceName: 'release-test-connection' # Change to whatever you named the service connection
              fileType: 'vsix'
              vsixFile: '$(PublisherID).$(ExtensionName)/$(PublisherID)..vsix'
              publisherId: '$(PublisherID)'
              extensionId: '$(ExtensionID)'
              extensionName: '$(ExtensionName)'
              updateTasksVersion: false
              extensionVisibility: 'private' # Change to public if you're publishing to the marketplace
              extensionPricing: 'free'

```


This will allow the pipeline automatically start building the package and update the extension onto the marketplace.

However, in order to enable this pipeline, you may need to:

### Step 1. Create an organization as well as a project on Azure DevOps. 

See [Create a project - Azure DevOps | Microsoft Docs](https://docs.microsoft.com/en-us/azure/devops/organizations/projects/create-project?tabs=browser&view=azure-devops).

### Step 2. Install Azure DevOps Extension Task to your Azure DevOps organization. 

See [Azure DevOps Extension Tasks - Visual Studio Marketplace](https://marketplace.visualstudio.com/items?itemName=ms-devlabs.vsts-developer-tools-build-tasks&targetId=85fb3d5a-9f21-420f-8de3-fc80bf29054b&utm_source=vstsproduct&utm_medium=ExtHubManageList).

### Step 3. Generate a personal access token on Azure DevOps. 

This token will be used later when we create a service connection. Configure the authorization scope for the token as follows or refer to [Azure DevOps Extension Tasks - Visual Studio Marketplace](https://marketplace.visualstudio.com/items?itemName=ms-devlabs.vsts-developer-tools-build-tasks&targetId=85fb3d5a-9f21-420f-8de3-fc80bf29054b&utm_source=vstsproduct&utm_medium=ExtHubManageList).

![Image](images/readme-personal-access-token.png)

![Image](images/readme-token-scopes.png)


### Step 4. Create a service connection in order to authorize the pipeline’s agent for accessing Visual Studio MarketPlace.

On how to create a service connection, see [Service connections in Azure Pipelines - Azure Pipelines | Microsoft Docs](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints?tabs=yaml&view=azure-devops). Note that you may need to select Visual Studio Marketplace for the service connection type.

![Image](images/readme-service-connections.png)


### Step 5. Compose the .yml file.

After all the previous steps, you are now able to create a build and release pipeline using the template we mentioned at the beginning. This task will be automatically packaged and updated to the marketplace once the pipeline is triggered.
