{%- for user in database.users %}

postgresql_user_{{ svr_name|default('localhost') }}_{{ database_name }}_{{ user.name }}:
  postgres_user.present:
    - name: {{ user.name }}
    - user: postgres
    {% if user.get('createdb', False) %}
    - createdb: enabled
    {% endif %}
    - password: {{ user.password }}
    {%- if server is defined %}
    - require:
        - service: postgresql_service
    {%- endif %}
    {%- if admin is defined %}
    {%- for k, p in admin.iteritems() %}
    - db_{{ k }}: {{ p }}
    {%- endfor %}
    - user: root
    {%- endif %}

{%- endfor %}

postgresql_database_{{ svr_name|default('localhost') }}_{{ database_name }}:
  postgres_database.present:
    - name: {{ database.get('name', database_name) }}
    - encoding: {{ database.encoding }}
    - user: postgres
    - template: template0
    - owner: {% for user in database.users %}{% if loop.first %}{{ user.name }}{% endif %}{% endfor %}
    - require:
        {%- for user in database.users %}
        - postgres_user: postgresql_user_{{ svr_name|default('localhost') }}_{{ database_name }}_{{ user.name }}
        {%- endfor %}
    {%- if admin is defined %}
    {%- for k, p in admin.iteritems() %}
    - db_{{ k }}: {{ p }}
    {%- endfor %}
    - user: root
    {%- endif %}

{%- if database.init is defined and database.init.queries is defined %}
{%- for query in database.init.get('queries', []) %}
postgresql_database_{{ svr_name|default('localhost') }}_{{ database.init.get('maintenance_db', database_name) }}_{{ loop.index }}:
  cmd.run:
    - name: "PGPASSWORD={{ admin.get('password') }} \
           psql -h {{ admin.get('host', 'localhost') }} \
           -U {{ admin.get('user', 'root') }} \
           -d {{ database.init.get('maintenance_db', database_name) }} \
           -c \"{{ query }} \" "
{%- endfor %}
{%- endif %}

{%- if database.initial_data is defined %}

{%- set engine = database.initial_data.get("engine", "backupninja") %}

/root/postgresql/scripts/restore_{{ database_name }}.sh:
  file.managed:
    - source: salt://postgresql/files/restore.sh
    - mode: 770
    - template: jinja
    - defaults:
      database_name: {{ database_name }}
    - require:
        - file: postgresql_dirs
        - postgres_database: postgresql_database_{{ database_name }}

restore_postgresql_database_{{ database_name }}:
  cmd.run:
    - name: /root/postgresql/scripts/restore_{{ database_name }}.sh
    - unless: "[ -f /root/postgresql/flags/{{ database_name }}-installed ]"
    - cwd: /root
    - require:
        - file: /root/postgresql/scripts/restore_{{ database_name }}.sh

{%- endif %}
