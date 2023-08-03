import axios, { AxiosRequestConfig, AxiosResponse } from 'axios';

const headers = {
  Accept: 'application/json',
  'Content-Type': 'application/json; charset=utf-8',
  'Access-Control-Allow-Credentials': true,
  'X-Requested-With': 'XMLHttpRequest',
};

const baseURL = 'https://management.azure.com';

class SimplifiedHttp {
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
