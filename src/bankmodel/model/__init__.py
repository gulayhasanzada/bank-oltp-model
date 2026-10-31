"""The bank model: source of truth for every generated document and the DDL.

Domain order here is the order used in all generated output.
"""

from bankmodel.model import (
    account,
    card,
    compliance,
    ledger,
    loan,
    organization,
    party,
    payment,
    reference,
)
from bankmodel.model.glossary import GLOSSARY

DOMAINS = (
    reference.DOMAIN,
    organization.DOMAIN,
    party.DOMAIN,
    account.DOMAIN,
    payment.DOMAIN,
    card.DOMAIN,
    loan.DOMAIN,
    ledger.DOMAIN,
    compliance.DOMAIN,
)

__all__ = ["DOMAINS", "GLOSSARY"]
