<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="xml" version="1.0" indent="yes" omit-xml-declaration="no"/>
<xsl:strip-space elements="*"/>
<xsl:param name="FPGA_DEVICE"/>
<xsl:param name="CONSTRAINTS_FILE"/>
<xsl:param name="TOP_MODULE"/>
<xsl:param name="TOP_MODULE_FILE"/>
<xsl:param name="VERILOG_FILES"/>
<xsl:param name="VHDL_FILES"/>
<xsl:template match="node()|@*">
  <xsl:copy>
    <xsl:apply-templates select="node()|@*"/>
  </xsl:copy>
</xsl:template>
<xsl:template match="BaliProject/@device">
  <xsl:attribute name="device">
    <xsl:value-of select="$FPGA_DEVICE"/>
  </xsl:attribute>
</xsl:template>
<xsl:template match="BaliProject/Implementation/Options/@top">
  <xsl:attribute name="top">
    <xsl:value-of select="$TOP_MODULE"/>
  </xsl:attribute>
</xsl:template>
<xsl:template match="BaliProject/Implementation/Options/@def_top">
  <xsl:attribute name="def_top">
    <xsl:value-of select="$TOP_MODULE"/>
  </xsl:attribute>
</xsl:template>

<xsl:template match="BaliProject/Implementation/Source[@type_short='LPF']/@name">
  <xsl:attribute name="name">
    <xsl:value-of select="$CONSTRAINTS_FILE"/>
  </xsl:attribute>
</xsl:template>

<xsl:template match="BaliProject/Implementation/Options">
  <xsl:copy>
    <xsl:apply-templates select="node()|@*"/>
  </xsl:copy>
  <xsl:call-template name="tokenize">
    <xsl:with-param name="string" select="normalize-space($VHDL_FILES)"/>
    <xsl:with-param name="type" select="'VHDL'"/>
  </xsl:call-template>
  <xsl:call-template name="tokenize">
    <xsl:with-param name="string" select="normalize-space($VERILOG_FILES)"/>
    <xsl:with-param name="type" select="'Verilog'"/>
  </xsl:call-template>
</xsl:template>

<xsl:template name="tokenize">
  <xsl:param name="string"/>
  <xsl:param name="type"/>
  <xsl:choose>
    <xsl:when test="contains($string,' ')">
      <xsl:element name="Source">
        <xsl:attribute name="name">
          <xsl:value-of select="substring-before($string,' ')"/>
        </xsl:attribute>
        <xsl:attribute name="type">
          <xsl:value-of select="$type"/>
        </xsl:attribute>
        <xsl:attribute name="type_short">
          <xsl:value-of select="$type"/>
        </xsl:attribute>
        <xsl:element name="Options">
          <xsl:if test="substring-before($string,' ')=$TOP_MODULE_FILE">
            <xsl:attribute name="top_module">
              <xsl:value-of select="$TOP_MODULE"/>
            </xsl:attribute>
          </xsl:if>
        </xsl:element>
      </xsl:element>
      <xsl:call-template name="tokenize">
        <xsl:with-param name="string" select="substring-after($string,' ')"/>
        <xsl:with-param name="type" select="$type"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:if test="$string != ''">
      <xsl:element name="Source">
        <xsl:attribute name="name">
          <xsl:value-of select="$string"/>
        </xsl:attribute>
        <xsl:attribute name="type">
          <xsl:value-of select="$type"/>
        </xsl:attribute>
        <xsl:attribute name="type_short">
          <xsl:value-of select="$type"/>
        </xsl:attribute>
        <xsl:element name="Options">
          <xsl:if test="$string=$TOP_MODULE_FILE">
            <xsl:attribute name="top_module">
              <xsl:value-of select="$TOP_MODULE"/>
            </xsl:attribute>
          </xsl:if>
        </xsl:element>
      </xsl:element>
      </xsl:if>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

</xsl:stylesheet>
