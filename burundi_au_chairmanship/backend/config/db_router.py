"""
Database router for read replica support.

Routes read-only queries to the replica database when available,
while ensuring all writes go to the primary database.
"""


class ReadReplicaRouter:
    """Route read queries to replica, writes to primary."""

    # Models that should always read from primary (real-time accuracy needed)
    PRIMARY_ONLY_MODELS = {
        'auth', 'sessions', 'token_blacklist', 'admin',
    }

    def db_for_read(self, model, **hints):
        if model._meta.app_label in self.PRIMARY_ONLY_MODELS:
            return 'default'
        return 'replica'

    def db_for_write(self, model, **hints):
        return 'default'

    def allow_relation(self, obj1, obj2, **hints):
        return True

    def allow_migrate(self, db, app_label, model_name=None, **hints):
        return db == 'default'
