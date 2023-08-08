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
} from './utils/file-handler';
import {
    validatedEnvVar,
    validatedAuthParams,
} from './utils/validation';
import { 
    ClientSecretCredential,
    AuthenticationError,
} from '@azure/identity';
import { info } from 'console';

/**
 * Class ConfigUpdater is responsible for updating the Nginx configuration.
 * It provides methods to authenticate, compress, and upload user-specific configurations
 * using Azure identity and other utilities.
*/
class ConfigUpdater {

    private f = new FileHandler;

    /**
     * Retrieves the authorization token for later authentication by using Azure identity.
     * @returns {Promise<any>} The authorization token.
     * @throws {Error} If the authorization parameters validation fails.
     * @throws {AuthenticationError} If the access token fetch fails.
    */
    private getAuthorizationTokenFromKey = async (
        tenantID: string,
        clientID: string,
        servicePrincipalKey: string
    ) => {
        try {
            const clientSecretCredential: ClientSecretCredential = new ClientSecretCredential(
                tenantID, clientID, servicePrincipalKey
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

    /**
     * Compresses the configuration file folder and prepares it for sending to the backend.
     * @returns {Promise<Object>} An object containing properties related to the compressed file.
     */
    private getConvertedFileObject = async () => {
        const file = await this.f.compressFile(
            validatedEnvVar(INPUT.source),
            validatedEnvVar(INPUT.target),
            OUTPUT_PATH,
        );
        return {
            properties: {
                rootFile: `${validatedEnvVar(INPUT.target)}/${validatedEnvVar(INPUT.rootFile)}`.replace(/\/\/+/g, '/'),
                package: {
                    data: this.f.convertFileToBase64String(file),
                }
            }
        };
    }

    /**
     * Constructs the request configuration, including the bearer token from the user's input.
     * @returns {Promise<AxiosRequestConfig>} The request configuration.
     */
    private getRequestConfig = async () => {
        const token = await this.getAuthorizationTokenFromKey(
            validatedAuthParams('tenantid'),
            validatedAuthParams('servicePrincipalId'),
            validatedAuthParams('servicePrincipalKey'),
        );
        const config: AxiosRequestConfig = { headers: {
            Authorization: `Bearer ${token.token}`,
        }}
        return config;
    }

    /**
     * Constructs the required parameters for the uploading API request.
     * @returns {Object} An object containing the required parameters for the request,
     * including subscription ID, resource group name, deployment name, and API version.
     */
    private getRequestResource = () => {
        return {
            subscriptionId: validatedEnvVar(INPUT.subscription),
            resourceGroupName: validatedEnvVar(INPUT.resource),
            deploymentName: validatedEnvVar(INPUT.deployment),
            apiVersion: API_VERSION,
        }
    }

    /**
     * Main function to compress the file, retrieve authentication info, and call the API to update the Nginx configuration.
     * @throws {Error} If the Nginx configuration uploading fails.
    */
    updateNginxConfig = async () => {
        console.log('updateNginxConfig...')
        try {
            const res = await updateUserConfig(
                this.getRequestResource(),
                await this.getConvertedFileObject(),
                await this.getRequestConfig(),
            );
            console.log('Nginx config successfully uploaded!');
        } catch (error) {
            taskLib.setResult(taskLib.TaskResult.Failed, error as any);
            throw new Error("Nginx config uploading failed!"); 
        }
    };
}

const updater = new ConfigUpdater();
updater.updateNginxConfig();
