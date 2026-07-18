"""Pricing helpers: take a percentage off a price, and round a price to something a buyer reads.

Both are PURE — no I/O, no marketplace call, nothing to guard. They compute a number that a
`market.reprice` node downstream then acts on, which is where the money actually moves and where
that node's own guard lives.

Money is Decimal here, never float. ``0.1 + 0.2`` is not ``0.3``, and a price that drifts by a
kopeck per run drifts by a lot over a month of a scheduled flow. The value crosses the flow's port
boundary as a string for the same reason — a float port would undo the Decimal.
"""

from __future__ import annotations

from decimal import ROUND_HALF_UP, Decimal, InvalidOperation

from pydantic import Field

from app.core.schema import BaseSchema
from app.domain.catalog.capabilities import NodeCapability
from app.domain.catalog.registry import NodeCategory, NodeRegistration, NodeType
from app.domain.flow_engine.base_node import BaseNode, RunContext
from app.domain.flow_engine.dtos import StepResultDTO
from app.domain.flow_engine.errors import RunFailed

_CENT = Decimal("0.01")


def _as_decimal(value: object, port: str, ctx: RunContext) -> Decimal:
    try:
        return Decimal(str(value))
    except (InvalidOperation, ValueError) as exc:
        raise RunFailed(ctx.run_id, ctx.node.id, f"{port} is not a number: {value!r}") from exc


class DiscountInput(BaseSchema):
    price: str = Field(title="Цена", json_schema_extra={"ui": "text"})
    percent: float = Field(
        title="Скидка, %", gt=0, lt=100, json_schema_extra={"ui": "number"}
    )


class DiscountOutput(BaseSchema):
    price: str


class DiscountNode(BaseNode):
    node_type = "pricing.discount"
    required_inputs = ("price", "percent")

    async def execute(self, ctx: RunContext) -> StepResultDTO:
        price = _as_decimal(ctx.resolve_input("price"), "price", ctx)
        percent = _as_decimal(ctx.resolve_input("percent"), "percent", ctx)
        cut = (price * (Decimal(100) - percent) / Decimal(100)).quantize(_CENT, ROUND_HALF_UP)
        return StepResultDTO(node_id=ctx.node.id, output={"price": str(cut)})


class PrettyPriceInput(BaseSchema):
    price: str = Field(title="Цена", json_schema_extra={"ui": "text"})
    ending: int = Field(
        default=99,
        title="Окончание",
        description="До какого хвоста округлять вниз: 99 даёт 1999 из 2043.",
        ge=0,
        le=999,
        json_schema_extra={"ui": "number"},
    )


class PrettyPriceOutput(BaseSchema):
    price: str


class PrettyPriceNode(BaseNode):
    node_type = "pricing.pretty"
    required_inputs = ("price",)

    async def execute(self, ctx: RunContext) -> StepResultDTO:
        price = _as_decimal(ctx.resolve_input("price"), "price", ctx)
        ending = int(_as_decimal(ctx.resolve_optional("ending") or 99, "ending", ctx))

        # Rounds DOWN to the next X99 — never up. A pricing helper that quietly raised a price
        # would be a helper that sells at a number the operator did not choose.
        step = Decimal(10 ** len(str(ending)) if ending else 10)
        base = (price / step).to_integral_value(rounding="ROUND_FLOOR") * step
        pretty = base + Decimal(ending)
        if pretty > price:
            pretty -= step
        return StepResultDTO(node_id=ctx.node.id, output={"price": str(max(pretty, Decimal(0)))})


_PURE = frozenset({NodeCapability.PURE})

REGISTRATIONS = [
    NodeRegistration(
        node_type=NodeType(
            key=DiscountNode.node_type,
            category=NodeCategory.LOGIC,
            input_schema=DiscountInput,
            output_schema=DiscountOutput,
            idempotent=True,
            capabilities=_PURE,
        ),
        impl=DiscountNode,
    ),
    NodeRegistration(
        node_type=NodeType(
            key=PrettyPriceNode.node_type,
            category=NodeCategory.LOGIC,
            input_schema=PrettyPriceInput,
            output_schema=PrettyPriceOutput,
            idempotent=True,
            capabilities=_PURE,
        ),
        impl=PrettyPriceNode,
    ),
]
