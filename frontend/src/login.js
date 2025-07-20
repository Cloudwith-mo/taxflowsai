// src/login.js
import AWS from "aws-sdk";
import { CognitoUserPool } from "amazon-cognito-identity-js";

// --- Cognito User Pool configuration ---
const poolData = {
  UserPoolId: "us‑east‑1_WS1bBY4sQ",      // your user pool ID
  ClientId:   "7vkumiq86lap5de5195f6llkaa" // your app client ID
};
const userPool = new CognitoUserPool(poolData);

// --- Wire up your forms ---
const registerForm = document.getElementById("registerForm");
registerForm.onsubmit = e => {
  e.preventDefault();
  // ... your sign‑up code here ...
};

// etc. for loginForm, chooseCatForm, etc.
