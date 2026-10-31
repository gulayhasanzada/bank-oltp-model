import unittest
from dataclasses import replace

from bankmodel.meta import Rel, Unique
from bankmodel.model import DOMAINS
from bankmodel.validate import validate


class ValidateTest(unittest.TestCase):
    def test_model_is_valid(self):
        self.assertEqual(validate(DOMAINS), [])

    def test_unknown_parent_is_reported(self):
        first = DOMAINS[0]
        broken_entity = replace(first.entities[0], rels=(Rel("no_such_entity", "x"),))
        broken = (replace(first, entities=(broken_entity, *first.entities[1:])), *DOMAINS[1:])
        self.assertTrue(any("unknown entity 'no_such_entity'" in e for e in validate(broken)))

    def test_duplicate_fk_column_is_reported(self):
        first = DOMAINS[0]
        rels = (Rel("currency", "a"), Rel("currency", "b"))
        broken_entity = replace(first.entities[0], rels=rels)
        broken = (replace(first, entities=(broken_entity, *first.entities[1:])), *DOMAINS[1:])
        self.assertTrue(any("defined more than once" in e for e in validate(broken)))

    def test_partitioned_unique_key_must_include_partition_column(self):
        account = next(d for d in DOMAINS if d.schema == "account")
        txn = next(e for e in account.entities if e.name == "account_transaction")
        broken_txn = replace(txn, uniques=(Unique(("reference_number",)),))
        entities = tuple(broken_txn if e is txn else e for e in account.entities)
        broken = tuple(replace(d, entities=entities) if d is account else d for d in DOMAINS)
        self.assertTrue(any("must include partition column" in e for e in validate(broken)))


if __name__ == "__main__":
    unittest.main()
