from e2b import Template, default_build_logger
from template import template

import dotenv
dotenv.load_dotenv()

if __name__ == "__main__":
    Template.build(
        template,
        "step-analyzer",
        on_build_logs=default_build_logger(),
    )