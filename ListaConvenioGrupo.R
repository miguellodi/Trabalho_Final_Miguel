lista.de.pacotes = c("tidyverse","lubridate","janitor","readxl","stringr",
                     "repmis","survey","srvyr", "ggplot2", "plotly") # escreva a lista de pacotes
novos.pacotes <- lista.de.pacotes[!(lista.de.pacotes %in%
                                      installed.packages()[,"Package"])]
if(length(novos.pacotes) > 0) {install.packages(novos.pacotes)}
lapply(lista.de.pacotes, require, character.only=T)
rm(lista.de.pacotes,novos.pacotes)
gc()

siconv_convenio <- read_csv2("C:/Users/ML/Desktop/SICONV/siconv_convenio.csv")
siconv_desembolso <- read_csv2("C:/Users/ML/Desktop/SICONV/siconv_desembolso.csv")
siconv_proposta <- read_csv2("C:/Users/ML/Desktop/SICONV/siconv_proposta.csv")
siconv_pagamento <- read_csv2("C:/Users/ML/Desktop/SICONV/siconv_pagamento.csv")
DAP <- read_xlsx ("C:/Users/ML/Desktop/SICONV/dap.xlsx")

#Gera relat?rio de Acompanhamento dos Conv?nios SENAD/MJ
DAP <- DAP %>%
  mutate(NR_CONVENIO=as.integer(NR_CONVENIO))

ListaConvenioGrupo <- siconv_convenio %>% 
  select(ID_PROPOSTA, NR_CONVENIO, ANO, SIT_CONVENIO, SUBSITUACAO_CONV, 
         DIA_ASSIN_CONV, DIA_INIC_VIGENC_CONV, DIA_FIM_VIGENC_CONV, 
         DIA_LIMITE_PREST_CONTAS, IND_OPERA_OBTV, NR_PROCESSO, VL_DESEMBOLSADO_CONV, VL_GLOBAL_CONV,
         VL_REPASSE_CONV, VL_EMPENHADO_CONV, VL_CONTRAPARTIDA_CONV) %>% 
  left_join(siconv_proposta %>% select(ID_PROPOSTA, UF_PROPONENTE, MUNIC_PROPONENTE, NM_PROPONENTE, 
                                       OBJETO_PROPOSTA, NATUREZA_JURIDICA, COD_ORGAO, IDENTIF_PROPONENTE)) %>%
  left_join(siconv_desembolso %>% select(NR_CONVENIO, DT_ULT_DESEMBOLSO)) %>% 
  left_join(siconv_pagamento %>% select(NR_CONVENIO, VL_PAGO)) %>%
  filter(COD_ORGAO =="30912") %>% 
  left_join(DAP) %>% 
  group_by(NR_CONVENIO,Grupos, ANO, UF_PROPONENTE, MUNIC_PROPONENTE, 
           NM_PROPONENTE, `Representante antigo`, `NOVO representante`,
           `Coordenação responsável`, `Obs de distribuição`, `Responsável na CGPA`,
           Tema, Subtema, Origem, Prioridade, SIT_CONVENIO, SUBSITUACAO_CONV,
           OBJETO_PROPOSTA, DT_ULT_DESEMBOLSO, DIA_ASSIN_CONV, DIA_INIC_VIGENC_CONV,
           DIA_FIM_VIGENC_CONV, DIA_LIMITE_PREST_CONTAS, IND_OPERA_OBTV, NR_PROCESSO,
           VL_DESEMBOLSADO_CONV, VL_GLOBAL_CONV, VL_REPASSE_CONV, VL_EMPENHADO_CONV,
           VL_CONTRAPARTIDA_CONV, ID_PROPOSTA, NATUREZA_JURIDICA, IDENTIF_PROPONENTE) %>% 
  summarise(SomaValorPago=sum(VL_PAGO)) %>% 
  mutate(PercExec=SomaValorPago/VL_GLOBAL_CONV) %>% 
  mutate(RecebeuRecurso=ifelse(SomaValorPago>0, "SIM", "NÃO")) %>% 
  filter(!is.na(ANO))
  


write.table(ListaConvenioGrupo, file = "C:/Users/ML/Desktop/ListaConvenioGrupo.csv", 
            row.names=F, sep = ";")

#Atribuindo ano 2018 ?s proposta que ainda n?o viraram conv?nio na base do SICONV:
ListaConvenioGrupo <- ListaConvenioGrupo %>% ungroup() %>% 
  mutate(ANO=ifelse(is.na(ANO),2018,ANO))


#Traformando ListaConvenioGrupo$VL_REPASSE_CONV em Inteiro para prepara para gr?fico
ListaConvenioGrupo$VL_REPASSE_CONV <- 
  as.integer (ListaConvenioGrupo$VL_REPASSE_CONV)



#Total de repasse por UF e ANO(Colunas)
RepasseANO <- ListaConvenioGrupo %>%
  select(UF_PROPONENTE, VL_REPASSE_CONV, ANO) %>% 
  group_by(UF_PROPONENTE, ANO) %>%
  filter(!is.na(ANO)) %>% 
  summarise(SomaRepasse=sum(VL_REPASSE_CONV)) %>% 
  spread(ANO, SomaRepasse)
  
  

#Atribuindo 0 ao NAs da Tabela RepasseAnoUF
ListaConvenioGrupo <- ListaConvenioGrupo %>% ungroup() %>% 
  mutate(NR_CONVENIO=ifelse(is.na(NR_CONVENIO),0,NR_CONVENIO))


 #Quantidade de convênios por UF - Período 2008 - 2018
   theme_set(theme_bw(base_size = 18))
   ggplot(ListaConvenioGrupo,aes(as.factor(UF_PROPONENTE),fill=as.factor(ANO)))+
     geom_bar()+
     ggtitle("Total de convênios por ano e UF")+
     xlab("UF") + ylab("Contagem")+theme(legend.position="bottom")+ 
     theme(legend.text = element_text(face = "bold")) + 
     guides(fill=guide_legend(title="Ano"))+
     theme_bw()+
     theme(axis.text.x = element_text(angle = 90, hjust = 1, size =4))

#Gráfico de  Repasse por ano + intervalo de confiança:
   RepasseANO <- ListaConvenioGrupo %>%
     select(UF_PROPONENTE, VL_REPASSE_CONV, ANO) %>% 
     group_by(ANO) %>% 
     summarise(SomaRepasse=sum(VL_REPASSE_CONV)) %>% 
     mutate(Per1000=SomaRepasse/100)
   
   ggplot(RepasseANO,aes(x=ANO,y=Per1000))+
     geom_point()+
     geom_smooth(method="lm")+
     xlab("Ano de Repasse") +
     scale_x_continuous(breaks=c(2008, 2010, 2012, 2014, 2016, 2018),
                        labels = c('2008','2010','2012', '2014', '2016', '2018'))+
     ylab("Valor de repasse dividido por 100") +
      ggtitle("Repasse, Intervalo de confiança e tendência linear")
   
   
#Histograma Valor do Repasse
media <- mean(log(ListaConvenioGrupo$VL_REPASSE_CONV))
SD <- sd(log(ListaConvenioGrupo$VL_REPASSE_CONV))
  ggplot(data=ListaConvenioGrupo, aes(x=log(VL_REPASSE_CONV))) + 
  geom_histogram(aes(y = ..density..), binwidth=0.3, col="black", 
                 fill = "snow2") +
  geom_density(aes(y=..density..), color="dodgerblue")+
  stat_function(fun=dnorm, args=list(mean=media, sd=SD), color="red")+
    scale_x_discrete(breaks=NULL)+
  geom_rug() + 
  xlab("Valor do Repasse") + 
  ylab("Densidade") + 
  ggtitle("Histograma Valor do Repasse")

   #Quantidade de convênios por situação e natureza jurídica - Período 2008 - 2018
     ggplot(ListaConvenioGrupo,aes(as.factor(SIT_CONVENIO),fill=as.factor(ANO)))+
     geom_bar()+
     ggtitle("Total de convênios por situação e Natureza Jurídica")+
     xlab("Natureza Jurídica") + ylab("Contagem")+ 
     coord_flip()+
     guides(fill=guide_legend(title="Natureza Jurídica do conveniente")) +
     theme_bw() +
     na.omit()+
     theme(legend.position = "bottom")
     theme_bw()
   
   #Quantidade de convênios por UF - Período 2008 - 2018
     ggplot(ListaConvenioGrupo,aes(as.factor(UF_PROPONENTE),fill=as.factor(UF_PROPONENTE)))+
     geom_bar()+
     ggtitle("Total de convênios por UF")+
     xlab("") + ylab("")+
     coord_polar(start = 0)+
     guides(fill=FALSE)
     
     #Gráfico média qtd média
     totalrepasse <- ListaConvenioGrupo %>% 
       summarise(somabr=sum(VL_REPASSE_CONV))
     
     totalconvenios <- ListaConvenioGrupo %>% 
       summarise(n=n())
     
      Grafico1 <- ListaConvenioGrupo %>% 
       select(UF_PROPONENTE, VL_REPASSE_CONV) %>%
       group_by(UF_PROPONENTE) %>% 
       summarise(soma=sum(VL_REPASSE_CONV)) %>% 
       mutate(`%Repasse`=(soma/totalrepasse$somabr))

      totalrepasse <- totalrepasse %>% ungroup() %>% 
        mutate(`%Repasse`=as.integer(`%Repasse`))
     
     nNacional <-ListaConvenioGrupo %>% 
       summarise(n=n())
     
     Grafico2 <- ListaConvenioGrupo %>% 
       select(UF_PROPONENTE, NR_CONVENIO) %>% 
       group_by(UF_PROPONENTE) %>% 
       summarise(n=n()) %>% 
       mutate(`%Convênios`=((n/nNacional$n)))
     
     Grafico3 <- Grafico1 %>% 
       left_join(Grafico2)

     Grafico3 <- Grafico3 %>% 
       mutate(`% de Contratos`=ifelse(!is.na(UF_PROPONENTE)," ",UF_PROPONENTE))
     
     ggplot(data=Grafico3, aes(x=UF_PROPONENTE,
                               y=`%Repasse`, 
                               fill=`%Repasse`))+
       geom_bar(stat="identity")+
       scale_color_viridis_c()+
       geom_point(data= Grafico3, aes(x=UF_PROPONENTE, 
                                      y=`%Convênios`,
                                      shape=`% de Contratos`))+
       coord_flip()+
       scale_y_continuous(labels = scales::percent)+
       scale_fill_continuous(labels=scales::percent)+
       guides(fill=guide_legend(title="% de Repasse")) +
       labs(color="%Contrato")+
       ggtitle("Comparativo % Repasse UF e % contratos por UF")+
       ylab("Percentual de Repasse/Qtd Contratos") + xlab("UF")+
       theme(axis.text.y = element_text(size=7))