"""Foundry chat client factory.

Centralizes endpoint / deployment / credential wiring so each agent's main.py stays slim.
"""
from __future__ import annotations

import os

from agent_framework.openai import FoundryChatClient
from azure.identity.aio import DefaultAzureCredential


def build_chat_client() -> FoundryChatClient:
    """Build a FoundryChatClient from env vars.

    Required env:
        AZURE_AI_PROJECT_ENDPOINT
        FOUNDRY_MODEL_DEPLOYMENT_NAME (or AZURE_AI_MODEL_DEPLOYMENT_NAME)
    """
    endpoint = os.environ.get("AZURE_AI_PROJECT_ENDPOINT")
    deployment = (
        os.environ.get("FOUNDRY_MODEL_DEPLOYMENT_NAME")
        or os.environ.get("AZURE_AI_MODEL_DEPLOYMENT_NAME")
    )
    if not endpoint:
        raise RuntimeError(
            "AZURE_AI_PROJECT_ENDPOINT is required. Set via "
            "`$env:AZURE_AI_PROJECT_ENDPOINT = azd env get-value AZURE_AI_PROJECT_ENDPOINT`."
        )
    if not deployment:
        raise RuntimeError(
            "FOUNDRY_MODEL_DEPLOYMENT_NAME (or AZURE_AI_MODEL_DEPLOYMENT_NAME) is required."
        )

    return FoundryChatClient(
        endpoint=endpoint,
        deployment_name=deployment,
        credential=DefaultAzureCredential(),
    )
