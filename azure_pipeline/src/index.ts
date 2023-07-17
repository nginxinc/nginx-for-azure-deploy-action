import taskLib = require('azure-pipelines-task-lib/task');
import { AxiosRequestConfig  } from "axios";
import { updateUserConfig } from './utils/api';
import {
    API_VERSION,
    SCOPE,
    OUTPUT_PATH,
    INPUT,
} from './utils/constants';
import {
    FileHandler,
} from './utils/fileHandler';
import {
    validatedEnvVar,
    validatedAuthParams,
} from './utils/common';
import { 
    ClientSecretCredential,
    AuthenticationError,
} from '@azure/identity';
import { info } from 'console';


class ConfigUpdater {

    private f = new FileHandler;

    // getAuthorizationTokenFromKey():
    // a function takes user's input given in the .yml file
    // and request an bearer token for authentication of later authorization
    // using @azure/identity
    private getAuthorizationTokenFromKey = async () => {
        try {
            const params = {
                tenantID:  validatedAuthParams('tenantid'),
                clientID:  validatedAuthParams('servicePrincipalId'),
                servicePrincipalKey: validatedAuthParams('servicePrincipalKey'),
            }
            const clientSecretCredential: ClientSecretCredential = new ClientSecretCredential(
                params.tenantID, params.clientID, params.servicePrincipalKey
            );
            const accessToken = await clientSecretCredential.getToken(SCOPE);
            if (!accessToken) {
                throw new AuthenticationError(0, {
                    error: 'Access token fetch failed'
                });
            }
            return accessToken;
        } catch (e) {
            throw new Error("Authorization parameters validation failed");   
        }
    }

    // getConvertedFileObject():
    // compress config file folder
    // and make it ready for sending it to backend
    private getConvertedFileObject = async () => {
        const file = await this.f.compressFile(
            validatedEnvVar(INPUT.source),
            validatedEnvVar(INPUT.target),
            OUTPUT_PATH,
        );
        return {
            properties: {
                rootFile: `${validatedEnvVar(INPUT.target)}nginx.conf`,
                package: {
                    data: this.f.convertFileToBase64String(file),
                }
            }
        };
    }

    // getRequestConfig():
    // make up the bearer token from user's input
    private getRequestConfig = async () => {
        const token = await this.getAuthorizationTokenFromKey();
        const config: AxiosRequestConfig = { headers: {
            Authorization: `Bearer ${token.token}`,
        }}
        return config;
    }

    // getRequestResource():
    // make up all needed parameters for the uploading api request
    private getRequestResource = () => {
        return {
            subscriptionId: validatedEnvVar(INPUT.subscription),
            resourceGroupName: validatedEnvVar(INPUT.resource),
            deploymentName: validatedEnvVar(INPUT.deployment),
            apiVersion: API_VERSION,
        }
    }

    // updateNginxConfig():
    // main function to compress file, get authentication info, and call the api
    updateNginxConfig = async () => {
        console.log('updateNginxConfig...')
        try {
            const res = await updateUserConfig(
                this.getRequestResource(),
                await this.getConvertedFileObject(),
                await this.getRequestConfig(),
            );
            console.log('Nginx config successfully uploaded!\n');
        } catch (error) {
            taskLib.setResult(taskLib.TaskResult.Failed, error as any);
            throw new Error("Nginx config uploading failed!"); 
        }
    };
}

const updater = new ConfigUpdater();
updater.updateNginxConfig();
