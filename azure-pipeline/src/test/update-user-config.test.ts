import axios from 'axios';
import { updateUserConfig, ResourceInfo, UserConfig } from '../utils/api';

jest.mock('axios');

const mockedAxios = axios as jest.Mocked<typeof axios>;

const resource: ResourceInfo = {
  subscriptionId: 'subscriptionId',
  resourceGroupName: 'resourceGroupName',
  deploymentName: 'deploymentName',
  apiVersion: 'apiVersion',
};

const nginxConfig: UserConfig = {
  properties: {
    rootFile: '/etc/nginx/nginx.conf',
    files: [
      {
        virtualPath: '/etc/nginx/conf.d/default.conf',
        content: '...',
      },
    ],
  },
};

const defaultConfig = {
  baseURL: 'https://management.azure.com',
  headers: {
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json',
    'X-Requested-With': 'XMLHttpRequest',
    'Access-Control-Allow-Credentials': true,
  },
};

describe('updateUserConfig', () => {
  it('sends a PUT request with correct arguments', async () => {
    // Arrange
    const mockResponse = { data: {} };
    mockedAxios.put.mockResolvedValue(mockResponse);

    // Act
    await updateUserConfig(resource, nginxConfig);

    // Assert
    expect(mockedAxios.put).toHaveBeenCalledWith(
      `/subscriptions/${resource.subscriptionId}/resourceGroups/${resource.resourceGroupName}/providers/NGINX.NGINXPLUS/nginxDeployments/${resource.deploymentName}/configurations/default?api-version=${resource.apiVersion}`,
      nginxConfig,
      defaultConfig,
    );
  });

  it('throws an error when the request fails', async () => {
    // Arrange
    const mockError = new Error('Request failed');
    mockedAxios.put.mockRejectedValue(mockError);

    // Act and Assert
    await expect(updateUserConfig(resource, nginxConfig)).rejects.toThrow('Request failed');
  });

  it('throws an error when the resource argument is missing', async () => {
    // Act and Assert
    await expect(updateUserConfig({} as any, nginxConfig)).rejects.toThrow();
  });

  it('throws an error when the nginxConfig argument is missing', async () => {
    // Act and Assert
    await expect(updateUserConfig(resource, {} as any)).rejects.toThrow();
  });

  it('throws an error when the resource argument has missing properties', async () => {
    // Arrange
    const incompleteResource: Partial<ResourceInfo> = {
      subscriptionId: 'subscriptionId',
      resourceGroupName: 'resourceGroupName',
      // deploymentName is missing
      apiVersion: 'apiVersion',
    };

    // Act and Assert
    await expect(updateUserConfig(incompleteResource as ResourceInfo, nginxConfig)).rejects.toThrow();
  });
});
