import { http } from "./http";
import { AxiosRequestConfig } from "axios";

export type UserConfig = {
    properties: {
        rootFile: string;
        files?: NginxConfigurationFile[];
        package?: NginxConfigurationPackage;
    };
};

export type NginxConfigurationFile = {
    virtualPath: string;
    content: string;
}

export type NginxConfigurationPackage = {
    data: string;
}

export type ResourceInfo = {
    subscriptionId: string;
    resourceGroupName: string;
    deploymentName: string;
    apiVersion: string;
}


export const updateUserConfig = async (
    resource: ResourceInfo,
    nginxConfig: UserConfig,
    config?: AxiosRequestConfig,
): Promise<any> => {
    return await http.put<UserConfig>(
        `/subscriptions/${resource.subscriptionId}/resourceGroups/${resource.resourceGroupName}/providers/NGINX.NGINXPLUS/nginxDeployments/${resource.deploymentName}/configurations/default?api-version=${resource.apiVersion}`,
        nginxConfig, config,
    );
};


