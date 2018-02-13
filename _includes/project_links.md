
{% for project in include.projects %}
[{{project.pages}}]: {{project.url}}
{%- assign pages = project.pages | split: '-' %}
{% for page in pages %}
[{{page}}]: {{project.url}}
{% endfor %}
{% endfor %}
