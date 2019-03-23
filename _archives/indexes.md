---
layout: archives
name: Indexes
permalink: /archive/indexes/
banner: true
---

<div class="row">
  <div class="col s12 m6 l4">
    <div class="collection with-header">
      <h4 class="collection-header">Cumulative</h4>
      {% for index in site.indexes reversed %}
      {%- if index.name and index.volume == 'all' -%}
        <a href="{{index.url}}" class="waves-effect collection-item">Index of {{index.name}}</a>
      {%- endif -%}
      {% endfor %}
    </div>
  </div>
</div>
<div class="row">
  {% for volume in site.volumes reversed %}
  {%- assign sub_items = site.indexes | where: "volume", volume.name -%}
  {%- if sub_items.size > 0 -%}
  <div class="col s12 m4 l3">
    <div class="collection with-header">
      <h4 class="collection-header">{{volume.name}}</h4>
      {% for item in sub_items reversed %}
        <a href="{{item.url}}" class="waves-effect collection-item">{{item.name}}</a>
      {% endfor %}
    </div>
  </div>
  {%- endif -%}
  {% endfor %}
</div>
