#!/bin/bash

# Simple automated HTML template

cat <<EOF
 _EOF_
<!doctype html>
<html>
<head>
  <title>OSARIS processing summary</title>
</head>

<body>
  
  <h1>OSARIS processing summary</h1>

  <h2>I. Processing result preview</h2>
  
  <table>
    <tr>
      <th>Cohence</th>
      <th>Interferogram (raw)</th>
      <th>Interferogram (unwr.)</th>
      <th>Days between scenes</th>
    </tr>
    <tr>
      <td colspan="4">
        <strong> __scene1__ <br> __scene2___</strong>
      </td>
    <tr>
      <td><img src="___coherence_img__" alt="Coherence"></td>
      <td><img src="___phase_img__" alt="Raw interferogram"></td>
      <td><img src="___unwrapped_img__" alt="Unwrapped interferogram"></td>
      <td>__Days_diff__</td>
    </tr>
  </table>


  
  <h2>II. Processing statistics</h2>
  
  <table>
    <tr>
      <td>Number of scenes</td>
      <td>_____</td>
    </tr>
    <tr>
      <td>Total processing time</td>
      <td>_____</td>
    </tr>
  </table>

</body>

</html>
_EOF_
EOF
