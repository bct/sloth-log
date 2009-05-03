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

<xsl:param name="blog-title"/>
<xsl:param name="http-root"/>
<xsl:param name="css-url"/>

<!-- the basic skeleton -->
<xsl:template match="/">
	<html>
	<head>
    <xsl:call-template name="html-head"/>
	</head>
	<!-- this should be elsewhere -->
	<body>
		<div id="header"><xsl:call-template name="header"/></div>
    <div id="content">
      <xsl:apply-templates select="//atom:entry"/>
    </div>
	</body>
	</html>
</xsl:template>

<xsl:template name="html-head">
  <title><xsl:call-template name="title"/></title>
  <xsl:if test="$css-url">
    <link rel="stylesheet" type="text/css" href="{$css-url}"/>
  </xsl:if>
  <link rel="alternate feed" type="application/atom+xml" href="{$http-root}/index.atom"/>
</xsl:template>

<xsl:template name="title">
  <xsl:choose>
    <xsl:when test="name(/*)='entry'">
      <xsl:value-of select="/*/atom:title"/> : <xsl:value-of select="$blog-title"/>
    </xsl:when>
    <xsl:otherwise><xsl:value-of select="/*/atom:title"/></xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template name="header">
  <strong><a href="{$http-root}/"><xsl:value-of select="$blog-title"/></a></strong>
  <div id="sections" class="tabs">
    <a href="{$http-root}/index.atom" class="feed">feed</a>
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
  <xsl:if test="./node()"><!-- don't output empty titles -->
    <h1 class="entry-title">
      <a href="{$http-root}/{../@ibes:slug}.html">
        <xsl:value-of select="text()"/>
      </a>
    </h1>
  </xsl:if>
</xsl:template>

<xsl:template name="item-info">
	<div class="entrymeta">
    <a rel="bookmark" href="{$http-root}/{@ibes:slug}.html">
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
      <xsl:value-of select="."/><xsl:if test="not(position()=last())"> ∩ </xsl:if>
		</xsl:for-each>
	</span>
</xsl:template>

<xsl:template match="atom:published|atom:updated">
	<xsl:value-of select="."/>
</xsl:template>

</xsl:stylesheet>
