"""add customer and bvn

Revision ID: 002
Revises: 001
Create Date: 2026-06-14 22:45:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '002'
down_revision: Union[str, None] = '001'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade() -> None:
    # 1. Create customers table
    op.create_table(
        'customers',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('customer_id', sa.String(), nullable=False),
        sa.Column('bvn', sa.String(), nullable=False),
        sa.Column('email', sa.String(), nullable=False),
        sa.Column('phone', sa.String(), nullable=False),
        sa.Column('created_at', sa.Float(), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_customers_customer_id'), 'customers', ['customer_id'], unique=True)
    op.create_index(op.f('ix_customers_id'), 'customers', ['id'], unique=False)
    op.create_index(op.f('ix_customers_bvn'), 'customers', ['bvn'], unique=False)

    # 2. Add bvn column to liveness_sessions table
    op.add_column('liveness_sessions', sa.Column('bvn', sa.String(), nullable=True))
    op.create_index(op.f('ix_liveness_sessions_bvn'), 'liveness_sessions', ['bvn'], unique=False)

def downgrade() -> None:
    op.drop_index(op.f('ix_liveness_sessions_bvn'), table_name='liveness_sessions')
    op.drop_column('liveness_sessions', 'bvn')
    op.drop_index(op.f('ix_customers_bvn'), table_name='customers')
    op.drop_index(op.f('ix_customers_id'), table_name='customers')
    op.drop_index(op.f('ix_customers_customer_id'), table_name='customers')
    op.drop_table('customers')
