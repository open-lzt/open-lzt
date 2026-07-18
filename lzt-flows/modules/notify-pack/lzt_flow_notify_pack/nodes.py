"""Notification nodes: Discord, and a generic signed webhook.

Both derive from ``BaseRequestNode``, which is not a convenience — it is the reason these are safe
to install. ``execute()`` is final there, so the egress fence, the retry/backoff and the timeout are
applied to every request whether this file wants them or not. A node here cannot reach the network
except through ``deps.http``, and ``deps.http`` cannot exist without an ``EgressPolicy``.

Neither node is MONEY: a duplicate notification is noise, not a loss, so neither needs a dedup
guard. Both are NETWORK_EGRESS and nothing else — which is what the operator sees in the catalog
before wiring one.

The operator must add the target host to ``LZT_FLOW_EGRESS_ALLOWED_HOSTS`` or every request here is
refused. That is the intended experience: naming a host is a deliberate act.
"""

from __future__ import annotations

from collections.abc import Mapping
from typing import Any

from pydantic import Field

from app.core.schema import BaseSchema
from app.domain.catalog.capabilities import NodeCapability
from app.domain.catalog.nodes.base_request import BaseRequestNode, HttpMethod, RequestSpec
from app.domain.catalog.registry import NodeCategory, NodeRegistration, NodeType
from app.domain.flow_engine.base_node import RunContext
from app.domain.flow_engine.dtos import StepResultDTO
from app.domain.flow_engine.errors import RunFailed

_TIMEOUT_S = 10.0
_HTTP_NO_CONTENT = 204
_HTTP_OK = 200


class DiscordInput(BaseSchema):
    webhook_url: str = Field(
        title="Вебхук Discord",
        description="URL вебхука канала. Он же и есть доступ к каналу — храните как пароль.",
        json_schema_extra={"ui": "secret"},
    )
    content: str = Field(title="Текст", min_length=1, json_schema_extra={"ui": "text"})


class DiscordOutput(BaseSchema):
    delivered: bool


class DiscordNotifyNode(BaseRequestNode):
    node_type = "notify.discord"
    required_inputs = ("webhook_url", "content")
    batchable = True

    def build_request(self, ctx: RunContext) -> RequestSpec:
        return RequestSpec(
            url=str(ctx.resolve_input("webhook_url")),
            method=HttpMethod.POST,
            headers={"Content-Type": "application/json"},
            json_body={"content": str(ctx.resolve_input("content"))[:2000]},
            timeout_s=_TIMEOUT_S,
        )

    def parse_response(
        self, ctx: RunContext, status: int, body: Mapping[str, Any]
    ) -> StepResultDTO:
        # Discord answers 204 with an empty body on success, so "no JSON" is the happy path here —
        # the transport reports that as {"error": "not_json"} and this node must not read it as a
        # failure.
        if status not in (_HTTP_OK, _HTTP_NO_CONTENT):
            raise RunFailed(
                ctx.run_id, ctx.node.id, f"discord refused the message: status={status}"
            )
        return StepResultDTO(node_id=ctx.node.id, output={"delivered": True})


class WebhookInput(BaseSchema):
    url: str = Field(
        title="URL вебхука",
        description="Хост должен быть в LZT_FLOW_EGRESS_ALLOWED_HOSTS, иначе запрос не уйдёт.",
        json_schema_extra={"ui": "text"},
    )
    payload: str = Field(
        title="Тело (JSON)",
        description="Отправляется как есть, строкой, в поле data.",
        json_schema_extra={"ui": "text"},
    )


class WebhookOutput(BaseSchema):
    status: int


class WebhookNode(BaseRequestNode):
    node_type = "notify.webhook"
    required_inputs = ("url", "payload")
    batchable = True

    def build_request(self, ctx: RunContext) -> RequestSpec:
        return RequestSpec(
            url=str(ctx.resolve_input("url")),
            method=HttpMethod.POST,
            headers={"Content-Type": "application/json"},
            json_body={"data": str(ctx.resolve_input("payload"))},
            timeout_s=_TIMEOUT_S,
        )

    def parse_response(
        self, ctx: RunContext, status: int, body: Mapping[str, Any]
    ) -> StepResultDTO:
        # The status is reported rather than judged: this node cannot know what a given endpoint
        # considers success, and 202/204 are as common as 200. The flow decides with logic.compare.
        #
        # This node DOES take a URL from the flow, which would be an SSRF primitive if the fence
        # were not upstream of it: the policy resolves the name, refuses every private address, and
        # connects to the address it checked. That is the only reason this input is acceptable.
        return StepResultDTO(node_id=ctx.node.id, output={"status": status})


_EGRESS = frozenset({NodeCapability.NETWORK_EGRESS})

REGISTRATIONS = [
    NodeRegistration(
        node_type=NodeType(
            key=DiscordNotifyNode.node_type,
            category=NodeCategory.ACTION,
            input_schema=DiscordInput,
            output_schema=DiscordOutput,
            idempotent=True,
            capabilities=_EGRESS,
        ),
        impl=DiscordNotifyNode,
    ),
    NodeRegistration(
        node_type=NodeType(
            key=WebhookNode.node_type,
            category=NodeCategory.ACTION,
            input_schema=WebhookInput,
            output_schema=WebhookOutput,
            idempotent=True,
            capabilities=_EGRESS,
        ),
        impl=WebhookNode,
    ),
]
