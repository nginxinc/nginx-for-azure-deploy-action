import tl = require('azure-pipelines-task-lib/task');
import { INPUT } from './constants';

export const validatedEnvVar = (inputName: string) => {
    const value = tl.getInput(inputName, true);
    if (!value) {
        throw new Error(`Varialbe ${inputName} not found!`);
    }
    return value;
}

export const validatedAuthParams = (inputName: string) => {
    const serviceConnectionName = validatedEnvVar(INPUT.connection);
    const value = tl.getEndpointAuthorizationParameter(serviceConnectionName, inputName, false)
    if (!value) {
        throw new Error(`Input varialbe ${inputName} not found!`);
    }
    return value;
}
