---
layout: archives
name: Indexes
permalink: /archives/indexes/
banner: true
---

<div class="row">
  {% for volume in site.volumes %}
  {%- assign sub_items = site.indexes | where: "volume", volume.name -%}
  {%- if sub_items.size > 0 -%}
  <div class="col s12 m4 l3">
    <div class="collection with-header">
      <h4 class="collection-header">{{volume.name}}</h4>
      {% for item in sub_items %}
        <a href="{{item.url}}" class="waves-effect collection-item">{{item.name}}</a>
      {% endfor %}
    </div>
  </div>
  {%- endif -%}
  {% endfor %}
</div>
<div class="row">
  <div class="col s12 m5 l4">
    <div class="collection with-header">
      <h4 class="collection-header">Cumulative</h4>
      {% for index in site.indexes %}
      {%- if index.name and index.volume == 'all' -%}
        <a href="{{index.url}}" class="waves-effect collection-item">All {{index.name}}</a>
      {%- endif -%}
      {% endfor %}
    </div>
  </div>
</div>
