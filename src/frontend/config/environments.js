// Environment-specific configurations
const environments = {
  development: {
    API_BASE: 'https://dev-api.taxflowsai.com',
    LOG_LEVEL: 'debug',
    ENABLE_ANALYTICS: false
  },
  staging: {
    API_BASE: 'https://staging-api.taxflowsai.com',
    LOG_LEVEL: 'info',
    ENABLE_ANALYTICS: true
  },
  production: {
    API_BASE: 'https://dql2om6jc.execute-api.us-east-1.amazonaws.com/default',
    LOG_LEVEL: 'error',
    ENABLE_ANALYTICS: true
  }
};

// Get current environment from build process or default to production
const currentEnv = process.env.NODE_ENV || 'production';
const config = environments[currentEnv] || environments.production;

export default config;