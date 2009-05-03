<xsl:stylesheet
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  version="1.0">
	<xsl:output
		method="html"
		indent="yes"
		encoding="UTF-8"
		doctype-public="-//W3C//DTD HTML 4.01//EN"
		doctype-system="http://www.w3.org/TR/html4/strict.dtd"
		media-type="text/html"/>

	<!-- shamelessly stolen from http://www.biglist.com/lists/xsl-list/archives/200004/msg00361.html -->

<xsl:template match="*">
	<xsl:element name="{local-name(.)}">
		<xsl:apply-templates select="@*|node()"/>
	</xsl:element>
</xsl:template>

<xsl:template match="@*">
	<xsl:attribute name="{local-name(.)}">
		<xsl:value-of select="."/>
	</xsl:attribute>
</xsl:template>

</xsl:stylesheet>
