"""add_is_adult_to_meetings

Revision ID: 75aa4a8f7a4e
Revises: 3c2f385872c1
Create Date: 2026-07-16 13:36:49.216378

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '75aa4a8f7a4e'
down_revision = '3c2f385872c1'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "meetings",
        sa.Column("is_adult", sa.Boolean(), nullable=False, server_default=sa.text("false")),
    )


def downgrade() -> None:
    op.drop_column("meetings", "is_adult")
