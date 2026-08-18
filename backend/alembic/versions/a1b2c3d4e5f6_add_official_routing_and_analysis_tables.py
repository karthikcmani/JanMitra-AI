"""add official routing and analysis tables

Revision ID: a1b2c3d4e5f6
Revises: 937ffb8a201e
Create Date: 2026-08-18 14:27:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


revision: str = 'a1b2c3d4e5f6'
down_revision: Union[str, None] = '937ffb8a201e'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('grievances', sa.Column('category', sa.String(length=150), nullable=True))
    op.add_column('grievances', sa.Column('department_id', sa.String(length=150), nullable=True))

    op.create_table(
        'grievance_analysis',
        sa.Column('id', sa.String(length=36), primary_key=True),
        sa.Column('grievance_id', sa.String(length=36), sa.ForeignKey('grievances.id', ondelete='CASCADE'), nullable=False),
        sa.Column('extracted_entities', sa.JSON(), nullable=True),
        sa.Column('predicted_category', sa.String(length=150), nullable=True),
        sa.Column('legal_grounding_references', sa.JSON(), nullable=True),
        sa.Column('ai_explanation', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    )


def downgrade() -> None:
    op.drop_table('grievance_analysis')
    op.drop_column('grievances', 'department_id')
    op.drop_column('grievances', 'category')
