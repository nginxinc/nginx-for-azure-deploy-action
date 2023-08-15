// TODO: API_VERSION could be changed to user selectable when there are multiple versions online
export const API_VERSION = '2021-05-01-preview';

export const SCOPE = 'https://management.azure.com/.default';

export const OUTPUT_PATH: string = './uploading-file.tar.gz';

export const INPUT = {
    connection: 'AZURESUBSCRIPTIONENDPOINT',
    resource: 'RESOURCEGROUPNAME',
    subscription: 'SUBSCRIPTIONID',
    deployment: 'DEPLOYMENTNAME',
    source: 'CONFIGDIRECTORYINREPO',
    target: 'CONFIGDIRECTORYINDEPLOYMENT',
    rootFile: 'ROOTCONFIGFILENAME',
}