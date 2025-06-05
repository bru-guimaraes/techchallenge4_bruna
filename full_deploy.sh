
---

# 🚀 **3️⃣ Guia_Recuperacao_EC2.md**

```markdown
# Guia de Recuperação Rápida do EC2

Se em algum momento o EC2 apresentar problemas:

### Reset completo:

```bash
cd ~
rm -rf techchallenge4_bruna

git clone https://github.com/bru-guimaraes/techchallenge4_bruna.git
cd techchallenge4_bruna
chmod +x full_deploy.sh
./full_deploy.sh
