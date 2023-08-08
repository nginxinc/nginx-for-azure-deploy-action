import axios, { AxiosRequestConfig, AxiosResponse } from 'axios';

const headers = {
  Accept: 'application/json',
  'Content-Type': 'application/json; charset=utf-8',
  'Access-Control-Allow-Credentials': true,
  'X-Requested-With': 'XMLHttpRequest',
};

const baseURL = 'https://management.azure.com';

/**
 * Class SimplifiedHttp provides a simplified interface for HTTP requests.
 * It encapsulates common configurations and error handling for making HTTP PUT requests.
 */
class SimplifiedHttp {
  /**
   * Makes an HTTP PUT request to the specified endpoint with the given data and configuration.
   * @param endpoint {string} The URL of the endpoint to send the request to.
   * @param data {T} Optional data to be sent in the request body.
   * @param config {AxiosRequestConfig} Optional configuration object for the request.
   * @returns {Promise<R>} A promise that resolves to the response of the request.
   * @throws {any} If an error occurs during the request.
   */
  put<T = any, R = AxiosResponse<T>>(endpoint: string, data?: T, config?: AxiosRequestConfig): Promise<R> {
    const finalConfig = {
      ...config,
      baseURL,
      headers: { ...headers, ...(config?.headers ?? {}) },
    };

    return axios.put<T, R>(endpoint, data, finalConfig)
      .catch((error: any) => {
        console.error('Error updating user config:', error);
        return Promise.reject(error);
      });
  }
}

export const http = new SimplifiedHttp();
