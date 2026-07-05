"""add is_blocked to users

Revision ID: 3c2f385872c1
Revises: df6e9e2ef62e
Create Date: 2026-07-05 06:16:34.721911

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '3c2f385872c1'
down_revision = 'df6e9e2ef62e'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('users', sa.Column('is_blocked', sa.Boolean(), nullable=False, server_default='false'))


def downgrade() -> None:
    op.drop_column('users', 'is_blocked')
