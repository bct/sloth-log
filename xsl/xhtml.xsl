<xsl:stylesheet 
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:math="http://exslt.org/math"
	xmlns:atom="http://www.w3.org/2005/Atom"
	xmlns:date="http://exslt.org/dates-and-times"
	xmlns:xhtml="http://www.w3.org/1999/xhtml"
  xmlns:ibes="http://necronomicorp.com/ns/ibes"
	xmlns="http://www.w3.org/1999/xhtml"
	exclude-result-prefixes="atom xhtml"
	extension-element-prefixes="date math"
	version="1.0">

<!-- XXX XSL indenting doesn't account for <pre/>. watch out. -->
<xsl:output
  method="xml"
  indent="yes"
	encoding="UTF-8" />

<!-- the lowest allowable n for <hn/>s converted from <h>s -->
<!-- h1 is a story title, h2 are subheadings -->
<xsl:param name="min-heading" select="2"/>

<!-- the basic skeleton -->
<xsl:template match="/">
	<html>
	<head>
    <title>[title]</title>
	</head>
	<!-- this should be elsewhere -->
	<body>
		<div id="header"><xsl:call-template name="header"/></div>
    <div id="content">
      <xsl:apply-templates select="//atom:entry"/>
    </div>
		<div id="links" class="yui-g">links</div>
	</body>
	</html>
</xsl:template>

<xsl:template name="header">
  <strong><a href="">[title]</a></strong>
  <div id="sections" class="tabs">
    <a href="">about</a>
    <a href="" class="feed">feed</a>
  </div>
  <div class="clear"/>
</xsl:template>

<xsl:template match="atom:entry">
  <div class="hentry">
    <xsl:attribute name="id">key-<xsl:value-of select="@ibes:slug"/></xsl:attribute>

    <xsl:apply-templates select="atom:title"/>
    <xsl:apply-templates select="atom:summary"/>
    <xsl:apply-templates select="atom:content"/>

    <xsl:call-template name="item-info"/>
  </div>

  <xsl:if test="atom:link[@rel='trackback']">
    <ul>
      <xsl:apply-templates select="atom:link[@rel='trackback']"/>
    </ul>
  </xsl:if>
</xsl:template>

<xsl:template match="atom:link[@rel='trackback']">
  <li><a href="{@href}"><xsl:value-of select="@title"/></a></li>
</xsl:template>

<xsl:template match="atom:content[@type='text']|atom:content[not(@type)]|atom:summary[@type='text']|atom:summary[not(@type)]">
  <div class="content text block">
    <xsl:apply-templates/>
  </div>
</xsl:template>

<xsl:template match="atom:content[starts-with(@type, 'image/')]">
  <xsl:choose>
    <xsl:when test="@src">
      <img class="content" src="{@src}" alt=""/>
    </xsl:when>
    <xsl:otherwise>
      <img class="content" src="data:{@type};base64,{translate(., ' &#xA;', '')}" alt=""/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- by default copy everything as-is (probably xhtml) -->
<xsl:template match="atom:content//*|atom:content//comment()|atom:content//text()" priority="-1">
  <xsl:copy>
    <xsl:apply-templates select="*|@*|comment()|processing-instruction()|text()"/>
	</xsl:copy>
</xsl:template>

<xsl:template match="atom:content//@*" priority="-1">
  <xsl:attribute name="{name()}"><xsl:value-of select="."/></xsl:attribute>
</xsl:template>

<xsl:template match="atom:content/xhtml:div">
 <div class="body">
   <xsl:apply-templates/>
 </div>
</xsl:template>

<xsl:template match="atom:title">
  <h1 class="entry-title">
    <a href="">
      <xsl:value-of select="text()"/>
    </a>
  </h1>
</xsl:template>

<!-- XHTML 2 -->
<xsl:template match="section">
	<xsl:apply-templates select="node()|text()|@*"/>
</xsl:template>

<!-- XHTML 2 -->
<xsl:template match="h">
	<xsl:variable name="level">
		<xsl:value-of select="count(ancestor::section) + $min-heading"/>
	</xsl:variable>
<!-- i should test that min-heading is changeable for comments and such. XXX -->
	<xsl:choose>
		<xsl:when test="$level > 6">
			<strong>
				<xsl:apply-templates select="@* | node()"/>
			</strong>
		</xsl:when>
		<xsl:otherwise>
			<xsl:element name="{concat('h',$level)}">
				<xsl:apply-templates select="@* | node()"/>
			</xsl:element>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="l">
	<xsl:apply-templates/><xsl:if test="not(position()=last())"><br/></xsl:if>
</xsl:template>

<xsl:template name="item-info">
	<div class="entrymeta">
    <a rel="bookmark" href="">
      #<xsl:value-of select="@ibes:slug"/>
    </a>

    <xsl:text> ┄  </xsl:text>

    <xsl:apply-templates select="atom:updated"/>

    <xsl:if test="atom:link[@rel='trackback']">
      <xsl:text> ┄  </xsl:text>

      tbs: <xsl:value-of select="count(atom:link[@rel='trackback'])"/>
    </xsl:if>

    <xsl:text> ┄  </xsl:text>

    <xsl:call-template name="tags"/>
	</div>
</xsl:template>

<xsl:template name="tags">
	<span class="tags">
    <xsl:for-each select="atom:category/@term">
      <a href="" rel="tag"><xsl:value-of select="."/></a><xsl:if test="not(position()=last())"> ∩ </xsl:if>
		</xsl:for-each>
	</span>
</xsl:template>

<xsl:template match="atom:published|atom:updated">
	<xsl:value-of select="."/>
</xsl:template>

<xsl:template name="prev-next" />

</xsl:stylesheet>
