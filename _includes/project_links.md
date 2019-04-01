
{% for project in include.projects %}
[{{project.pages}}]: {{project.url}} "{{project.title}} -- {{project.contributor}}"
{%- assign pages = project.pages | split: '-' %}
{% for page in pages %}
[{{page}}]: {{project.url}} "{{project.title}} -- {{project.contributor}}"
{% endfor %}
{% endfor %}
