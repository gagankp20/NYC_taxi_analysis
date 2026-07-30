select column1 as rate_code_id, column2 as rate_code_desc
from (values
    (1,  'Standard rate'),
    (2,  'JFK'),
    (3,  'Newark'),
    (4,  'Nassau or Westchester'),
    (5,  'Negotiated fare'),
    (6,  'Group ride'),
    (99, 'Unknown')
)